public with sharing class QuoteSignController {
    
    private static final String QUOTE_STATUS_SENT = 'Contract/ Quote Sent';
    
    @AuraEnabled
    public static String handleQuoteSign(Id quoteId) {
        try {
            if (quoteId == null) {
                throw new AuraHandledException('Quote ID cannot be null');
            }
            
            Quote q = [
                SELECT Id, Email, Account.Name
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];
            
            if (String.isBlank(q.Email)) {
                throw new AuraHandledException('No recipient email found for this Quote');
            }

            ZohoSignService.SignatureRequest signatureRequest = new ZohoSignService.SignatureRequest(
                quoteId,
                q.Account.Name,
                q.Email,
                'Quote Signature Request',
                'Status',
                QUOTE_STATUS_SENT,
                'Signed_Request_Id__c'
            );
            
            return ZohoSignService.processDocumentForSignature(signatureRequest);
            
        } catch (Exception e) {
            System.debug('Error in handleQuoteSign: ' + e.getMessage());
            throw new AuraHandledException('Failed to process quote signature: ' + e.getMessage());
        }
    }
}