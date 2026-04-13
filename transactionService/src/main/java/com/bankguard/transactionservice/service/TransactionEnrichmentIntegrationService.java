package com.bankguard.transactionservice.service;

import com.bankguard.transactionservice.dto.CustomerEnrichmentDTO;
import com.bankguard.transactionservice.dto.EnrichmentRequestDTO;
import com.bankguard.transactionservice.dto.TransactionEnrichmentDTO;
import com.bankguard.transactionservice.entity.Customer;
import com.bankguard.transactionservice.entity.Transaction;
import com.bankguard.transactionservice.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class TransactionEnrichmentIntegrationService {

    @Autowired
    private TransactionRepository transactionRepository;

    @Autowired
    private RestTemplate restTemplate;

    @Value("${enrichment.service.url:http://localhost:8010}")
    private String enrichmentServiceUrl;

    /**
     * Send transaction data to Enrichment Service
     * Includes: current transaction + customer profile + last 5 previous transactions
     */
    public Object enrichTransactionWithService(Transaction transaction, Customer customer) {
        try {
            // Create current transaction DTO
            TransactionEnrichmentDTO currentTransactionDTO = new TransactionEnrichmentDTO();
            currentTransactionDTO.setTransactionId(transaction.getTransactionId());
            currentTransactionDTO.setAmount(transaction.getAmount());
            currentTransactionDTO.setCity(transaction.getCity());
            currentTransactionDTO.setState(transaction.getState());
            currentTransactionDTO.setIpAddress(transaction.getIpAddress());
            currentTransactionDTO.setTime(transaction.getTime());
            currentTransactionDTO.setRiskScore(transaction.getRiskScore());
            currentTransactionDTO.setReceiverAccountNumber(transaction.getReceiverAccountNumber());
            currentTransactionDTO.setCustomerId(transaction.getCustomerId());

            // Create customer DTO
            CustomerEnrichmentDTO customerDTO = new CustomerEnrichmentDTO();
            if (customer != null) {
                customerDTO.setCustomerId(customer.getCustomerId());
                customerDTO.setBankName(customer.getBankName());
                customerDTO.setBalance(customer.getBalance());
                customerDTO.setAccountType(customer.getAccountType());
                customerDTO.setName(customer.getName());
                customerDTO.setEmail(customer.getEmail());
                customerDTO.setAccountNo(customer.getAccountNo());
            }

            // Get previous transactions (max 5, excluding current transaction)
            List<TransactionEnrichmentDTO> previousTransactionsDTO = getLastPreviousTransactions(
                    transaction.getCustomerId(), 
                    transaction.getTransactionId(), 
                    5
            );

            // Create enrichment request
            EnrichmentRequestDTO enrichmentRequest = new EnrichmentRequestDTO();
            enrichmentRequest.setCurrentTransaction(currentTransactionDTO);
            enrichmentRequest.setCustomer(customerDTO);
            enrichmentRequest.setPreviousTransactions(previousTransactionsDTO);

            // Send to Enrichment Service with Decision and Alert routing (includes Gemini analysis and AlertCase routing)
            String enrichmentUrl = enrichmentServiceUrl + "/api/enrich/transaction/with-decision-and-alert";
            Object enrichedResponse = restTemplate.postForObject(enrichmentUrl, enrichmentRequest, Object.class);

            return enrichedResponse;

        } catch (Exception e) {
            throw new RuntimeException("Error enriching transaction: " + e.getMessage(), e);
        }
    }

    /**
     * Get last N previous transactions for a customer (excluding current transaction)
     */
    private List<TransactionEnrichmentDTO> getLastPreviousTransactions(
            Long customerId, 
            Long excludeTransactionId, 
            int limit) {
        
        List<Transaction> allTransactions = transactionRepository.findByCustomerId(customerId);
        
        return allTransactions.stream()
                .filter(t -> !t.getTransactionId().equals(excludeTransactionId))
                .sorted((t1, t2) -> {
                    if (t2.getTime() == null || t1.getTime() == null) {
                        return 0;
                    }
                    return t2.getTime().compareTo(t1.getTime());
                })
                .limit(limit)
                .map(this::convertTransactionToDTO)
                .collect(Collectors.toList());
    }

    /**
     * Convert Transaction entity to TransactionEnrichmentDTO
     */
    private TransactionEnrichmentDTO convertTransactionToDTO(Transaction transaction) {
        TransactionEnrichmentDTO dto = new TransactionEnrichmentDTO();
        dto.setTransactionId(transaction.getTransactionId());
        dto.setAmount(transaction.getAmount());
        dto.setCity(transaction.getCity());
        dto.setState(transaction.getState());
        dto.setIpAddress(transaction.getIpAddress());
        dto.setTime(transaction.getTime());
        dto.setRiskScore(transaction.getRiskScore());
        dto.setReceiverAccountNumber(transaction.getReceiverAccountNumber());
        dto.setCustomerId(transaction.getCustomerId());
        return dto;
    }

    /**
     * Create and enrich a new transaction (before storing in database)
     * Sends transaction with customer profile and previous transactions to enrichment service
     */
    public Object createAndEnrichTransaction(Transaction transaction, Customer customer) {
        try {
            // Create current transaction DTO (without transactionId since it's new)
            TransactionEnrichmentDTO currentTransactionDTO = new TransactionEnrichmentDTO();
            currentTransactionDTO.setAmount(transaction.getAmount());
            currentTransactionDTO.setCity(transaction.getCity());
            currentTransactionDTO.setState(transaction.getState());
            currentTransactionDTO.setIpAddress(transaction.getIpAddress());
            currentTransactionDTO.setRiskScore(transaction.getRiskScore());
            currentTransactionDTO.setReceiverAccountNumber(transaction.getReceiverAccountNumber());
            currentTransactionDTO.setCustomerId(transaction.getCustomerId());

            // Create customer DTO
            CustomerEnrichmentDTO customerDTO = new CustomerEnrichmentDTO();
            if (customer != null) {
                customerDTO.setCustomerId(customer.getCustomerId());
                customerDTO.setBankName(customer.getBankName());
                customerDTO.setBalance(customer.getBalance());
                customerDTO.setAccountType(customer.getAccountType());
                customerDTO.setName(customer.getName());
                customerDTO.setEmail(customer.getEmail());
                customerDTO.setAccountNo(customer.getAccountNo());
            }

            // Get last 5 previous transactions for this customer
            List<Transaction> allTransactions = transactionRepository.findByCustomerId(transaction.getCustomerId());
            List<TransactionEnrichmentDTO> previousTransactionsDTO = allTransactions.stream()
                    .sorted((t1, t2) -> {
                        if (t2.getTime() == null || t1.getTime() == null) {
                            return 0;
                        }
                        return t2.getTime().compareTo(t1.getTime());
                    })
                    .limit(5)
                    .map(this::convertTransactionToDTO)
                    .collect(Collectors.toList());

            // Create enrichment request
            EnrichmentRequestDTO enrichmentRequest = new EnrichmentRequestDTO();
            enrichmentRequest.setCurrentTransaction(currentTransactionDTO);
            enrichmentRequest.setCustomer(customerDTO);
            enrichmentRequest.setPreviousTransactions(previousTransactionsDTO);

            // Send to Enrichment Service
            String enrichmentUrl = enrichmentServiceUrl + "/api/enrich/transaction";
            Object enrichedResponse = restTemplate.postForObject(enrichmentUrl, enrichmentRequest, Object.class);

            return enrichedResponse;

        } catch (Exception e) {
            throw new RuntimeException("Error creating and enriching transaction: " + e.getMessage(), e);
        }
    }
}
