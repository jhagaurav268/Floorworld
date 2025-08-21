public with sharing class QuotePdfController {
    public Quote quote { get; set; }
    public List<QuoteLineItem> quoteLineItems { get; set; }
    
    public QuotePdfController() {
        String quoteId = ApexPages.currentPage().getParameters().get('id');
        
        if (String.isNotBlank(quoteId)) {
            loadQuoteData(quoteId);
        }
    }
    
    public QuotePdfController(ApexPages.StandardController stdController) {
        String quoteId = stdController.getId();
        if (String.isNotBlank(quoteId)) {
            loadQuoteData(quoteId);
        }
    }
    //Goods_Available__c, Payment_Terms__c, Other_Instructions__c, Terms_and_Conditions__c, Account.TRN__c
    private void loadQuoteData(String quoteId) {
        try {
            quote = [SELECT Id, Name, QuoteNumber, CreatedDate, ExpirationDate,
                     Subtotal, Discount, Tax, TotalPrice, Email, Account.Phone,
                     Account.ShippingAddress, Account.ShippingStreet, Account.ShippingCity,
                     Supply_Type__c, Shipping_Method__c, Account.ShippingState,
                     Owner.Name, Account.BillingStreet, Account.BillingCity, Account.ShippingCountry,
                     Account.Name, Account.AccountNumber, Account.BillingState, Account.BillingCountry,
                     Contact.Name, Contact.Phone, Contact.MobilePhone, Contact.Email
                     FROM Quote 
                     WHERE Id = :quoteId 
                     LIMIT 1];
            
            quoteLineItems = [SELECT Id, Product2.Name, Product2.ProductCode, 
                              Description, Quantity, UnitPrice, TotalPrice,
                              Location__c
                              FROM QuoteLineItem 
                              WHERE QuoteId = :quoteId 
                              ORDER BY LineNumber ASC];
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                                                       'Error loading quote data: ' + e.getMessage()));
        }
    }
    
    public Decimal getVATPercentage() {
        return 5.0;
    }
    
    public Decimal getTaxableAmount() {
        if (quote != null) {
            return quote.Subtotal - (quote.Discount != null ? quote.Discount : 0);
        }
        return 0;
    }
}