package com.vms.backend.common;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, Object>> validation(MethodArgumentNotValidException ex,
                                                    HttpServletRequest request) {
        String message = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> e.getField() + ": " + e.getDefaultMessage())
            .distinct().collect(Collectors.joining("; "));
        return error(HttpStatus.BAD_REQUEST, message, request);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<Map<String, Object>> malformed(HttpMessageNotReadableException ex,
                                                   HttpServletRequest request) {
        return error(HttpStatus.BAD_REQUEST, "Invalid JSON or field value", request);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<Map<String, Object>> conflict(DataIntegrityViolationException ex,
                                                  HttpServletRequest request) {
        return error(HttpStatus.CONFLICT, "Record conflicts with an existing unique value", request);
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<Map<String, Object>> handled(ResponseStatusException ex,
                                                 HttpServletRequest request) {
        return error(HttpStatus.valueOf(ex.getStatusCode().value()), ex.getReason(), request);
    }

    private ResponseEntity<Map<String, Object>> error(HttpStatus status, String message,
                                                        HttpServletRequest request) {
        return ResponseEntity.status(status).body(Map.of(
            "timestamp", Instant.now().toString(),
            "status", status.value(),
            "message", message == null ? status.getReasonPhrase() : message,
            "path", request.getRequestURI()));
    }
}
