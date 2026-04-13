package com.bankguard.transactionservice.controller;

import com.bankguard.transactionservice.dto.TransactionCreationRequest;
import com.bankguard.transactionservice.entity.Customer;
import com.bankguard.transactionservice.entity.Transaction;
import com.bankguard.transactionservice.repository.CustomerRepository;
import com.bankguard.transactionservice.service.TransactionEnrichmentIntegrationService;
import com.bankguard.transactionservice.service.TransactionService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/transactions")
public class TransactionController {

    @Autowired
    private TransactionService transactionService;

    @Autowired
    private TransactionEnrichmentIntegrationService enrichmentIntegrationService;

    @Autowired
    private CustomerRepository customerRepository;

    /**
     * Create transaction with enrichment
     * Sends transaction data along with customer profile and previous 5 transactions to enrichment service
     * Then stores the transaction in the database
     */
 //   @PostMapping
//    public ResponseEntity<Map<String, Object>> createTransaction(@RequestBody TransactionCreationRequest request) {
//        try {
//            // Validate customer exists
//            Customer customer = customerRepository.findById(request.getCustomerId())
//                    .orElseThrow(() -> new IllegalArgumentException("Customer not found with ID: " + request.getCustomerId()));
//
//            // Create transaction entity from request
//            Transaction transaction = new Transaction();
//            transaction.setAmount(request.getAmount());
//            transaction.setCity(request.getCity());
//            transaction.setState(request.getState());
//            transaction.setIpAddress(request.getIpAddress());
//            transaction.setReceiverAccountNumber(request.getReceiverAccountNumber());
//            transaction.setCustomerId(request.getCustomerId());
//            transaction.setTime(LocalDateTime.now());
//            transaction.setRiskScore(0.0); // Default risk score, will be updated by enrichment service
//
//            // Send to enrichment service (with customer profile and previous transactions)
//            Object enrichedResponse = enrichmentIntegrationService.createAndEnrichTransaction(transaction, customer);
//
//            // Save transaction to database
//            Transaction savedTransaction = transactionService.saveTransaction(transaction);
//
//            // Return response with both saved transaction and enrichment response
//            return new ResponseEntity<>(
//                    Map.of(
//                            "transaction", savedTransaction,
//                            "enrichmentResponse", enrichedResponse
//                    ),
//                    HttpStatus.CREATED
//            );
//
//        } catch (IllegalArgumentException e) {
//            return new ResponseEntity<>(
//                    Map.of("error", e.getMessage()),
//                    HttpStatus.BAD_REQUEST
//            );
//        } catch (Exception e) {
//            return new ResponseEntity<>(
//                    Map.of("error", "Failed to create transaction: " + e.getMessage()),
//                    HttpStatus.INTERNAL_SERVER_ERROR
//            );
//        }
//    }


    @PostMapping
    public ResponseEntity<Map<String, Object>> createTransaction(@RequestBody TransactionCreationRequest request) {
        try {
            // 1. Validate customer exists
            Customer customer = customerRepository.findById(request.getCustomerId())
                    .orElseThrow(() -> new IllegalArgumentException("Customer not found with ID: " + request.getCustomerId()));

            // 2. Map Request to a transient (unsaved) Transaction Entity
            Transaction transaction = new Transaction();
            transaction.setAmount(request.getAmount());
            transaction.setCity(request.getCity());
            transaction.setState(request.getState());
            transaction.setIpAddress(request.getIpAddress());
            transaction.setReceiverAccountNumber(request.getReceiverAccountNumber());
            transaction.setCustomerId(request.getCustomerId());
            transaction.setTime(LocalDateTime.now());
            transaction.setRiskScore(0.0);

            // 3. Call enrichment service BEFORE saving
            // Note: transaction.getTransactionId() will be null here
            Object enrichedResponse = enrichmentIntegrationService.enrichTransactionWithService(transaction, customer);

            // 4. Save to database only AFTER enrichment is successful
            Transaction savedTransaction = transactionService.saveTransaction(transaction);

            return new ResponseEntity<>(
                    Map.of(
                            "transaction", savedTransaction,
                            "enrichmentResponse", enrichedResponse
                    ),
                    HttpStatus.CREATED
            );

        } catch (IllegalArgumentException e) {
            return new ResponseEntity<>(Map.of("error", e.getMessage()), HttpStatus.BAD_REQUEST);
        } catch (Exception e) {
            return new ResponseEntity<>(Map.of("error", e.getMessage()), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    @GetMapping
    public ResponseEntity<List<Transaction>> getAllTransactions() {
        List<Transaction> transactions = transactionService.getAllTransactions();
        return new ResponseEntity<>(transactions, HttpStatus.OK);
    }

    @GetMapping("/{transactionId}")
    public ResponseEntity<Transaction> getTransactionById(@PathVariable Long transactionId) {
        Transaction transaction = transactionService.getTransactionById(transactionId);
        if (transaction != null) {
            return new ResponseEntity<>(transaction, HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }

    @PutMapping("/{transactionId}")
    public ResponseEntity<Transaction> updateTransaction(@PathVariable Long transactionId, @RequestBody Transaction transactionDetails) {
        Transaction updatedTransaction = transactionService.updateTransaction(transactionId, transactionDetails);
        if (updatedTransaction != null) {
            return new ResponseEntity<>(updatedTransaction, HttpStatus.OK);
        }
        return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }

    @DeleteMapping("/{transactionId}")
    public ResponseEntity<String> deleteTransaction(@PathVariable Long transactionId) {
        boolean deleted = transactionService.deleteTransaction(transactionId);
        if (deleted) {
            return new ResponseEntity<>("Transaction deleted successfully", HttpStatus.OK);
        }
        return new ResponseEntity<>("Transaction not found", HttpStatus.NOT_FOUND);
    }

    @GetMapping("/customer/{customerId}")
    public ResponseEntity<List<Transaction>> getTransactionsByCustomerId(@PathVariable Long customerId) {
        List<Transaction> transactions = transactionService.getTransactionsByCustomerId(customerId);
        return new ResponseEntity<>(transactions, HttpStatus.OK);
    }

    @GetMapping("/receiver/{receiverAccountNumber}")
    public ResponseEntity<List<Transaction>> getTransactionsByReceiverAccount(@PathVariable String receiverAccountNumber) {
        List<Transaction> transactions = transactionService.getTransactionsByReceiverAccount(receiverAccountNumber);
        return new ResponseEntity<>(transactions, HttpStatus.OK);
    }
}
