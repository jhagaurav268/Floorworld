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
                     Supply_Type__c, Shipping_Method__c, Account.ShippingState, Good_Available__c,
                     Owner.Name, Account.BillingStreet, Account.BillingCity, Account.ShippingCountry,
                     Account.Name, Account.AccountNumber, Account.BillingState, Account.BillingCountry,
                     Contact.Name, Contact.Phone, Contact.MobilePhone, Contact.Email, Opportunity.Name,
                     Total_Price__c, Grand_Total__c, VAT__c, Tax_Amount__c, Discounted_Amount__c, Terms__c
                     FROM Quote 
                     WHERE Id = :quoteId 
                     LIMIT 1];
            
            quoteLineItems = [SELECT Id, Product2.Name, Product2.ProductCode, Gross_Amount__c, CurrencyIsoCode,
                              Description, Quantity, UnitPrice, TotalPrice, Discounted_Price__c, Quantity_SQM__c,
                              Location__c, Product2.Box_s_Per_Pallet__c, Product2.Weight_Per_Box_PCS_Kg__c,
                              Net_Area_Sqm_Lm__c, Unit__c, Product2.Primary_Consumption_Unit__c
                              FROM QuoteLineItem 
                              WHERE QuoteId = :quoteId 
                              AND (NOT (Product2.Name LIKE '%Discount%'
                                   OR Product2.Name LIKE '%discount%'
                                   OR Description LIKE '%discount%'
                                   OR Description LIKE '%Discount%'))
                              ORDER BY LineNumber ASC];
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                                                       'Error loading quote data: ' + e.getMessage()));
        }
    }
    
    public Decimal getVATPercentage() {
        return 5.0;
    }
}