public with sharing class InvoicePdfController {
    public Order order { get; set; }
    public List<OrderItem> orderProducts { get; set; }
    public Proforma_Invoice__c proformaInvoice { get; set; }
    
    public InvoicePdfController() {
        String orderId = ApexPages.currentPage().getParameters().get('id');
        
        if (String.isNotBlank(orderId)) {
            loadOrderData(orderId);
        }
    }
    
    public InvoicePdfController(ApexPages.StandardController stdController) {
        String orderId = stdController.getId();
        if (String.isNotBlank(orderId)) {
            loadOrderData(orderId);
        }
    }
    //Goods_Available__c, Payment_Terms__c, Other_Instructions__c, Terms_and_Conditions__c, Account.TRN__c
    private void loadOrderData(String orderId) {
        try {
            order = [SELECT Id, Name, OrderNumber, CreatedDate, Opportunity.Name, Sales_Rep__r.Name,
                     Total_Price__c, VAT__c, Tax_Amount__c, Grand_Total__c, Account.Phone, Branch__r.Name,
                     Account.ShippingAddress, Account.ShippingStreet, Account.ShippingCity,
                     Supply_Type__c, Shipping_Method__c, Account.ShippingState, Quote.Email, Branch__r.Branch_Phone__c,
                     Owner.Name, Account.BillingStreet, Account.BillingCity, Account.ShippingCountry, Account.ShippingPostalCode,
                     Account.Name, Account.AccountNumber, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                     Contact__r.Name, Contact__r.Phone, Contact__r.MobilePhone, Contact__r.Email, Branch__r.Branch_Address__c
                     FROM Order 
                     WHERE Id = :orderId 
                     LIMIT 1];
            
            orderProducts = [SELECT Id, Product2.Name, Product2.ProductCode, 
                              Description, Quantity, UnitPrice, TotalPrice,
                              Location__c
                              FROM OrderItem 
                              WHERE OrderId = :orderId
                             AND (NOT (Product2.Name LIKE '%Discount%'
                                   OR Product2.Name LIKE '%discount%'
                                   OR Description LIKE '%discount%'
                                   OR Description LIKE '%Discount%'))
                              Order By OrderItemNumber ASC];
            
            proformaInvoice = [SELECT Id, OwnerId, IsDeleted, Name, CurrencyIsoCode,
                               Order__c, Proforma_Invoice__c, Proforma_Invoice_Amount__c
                               FROM Proforma_Invoice__c WHERE Order__c =: orderId LIMIT 1];
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                                                       'Error loading quote data: ' + e.getMessage()));
        }
    }
    
    public Decimal getVATPercentage() {
        return 5.0;
    }
}