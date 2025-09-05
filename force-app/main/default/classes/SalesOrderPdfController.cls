public with sharing class SalesOrderPdfController {
    public Order order { get; set; }
    public List<OrderItem> orderProducts { get; set; }
    
    public SalesOrderPdfController() {
        String orderId = ApexPages.currentPage().getParameters().get('id');
        
        if (String.isNotBlank(orderId)) {
            loadOrderData(orderId);
        }
    }
    
    public SalesOrderPdfController(ApexPages.StandardController stdController) {
        String orderId = stdController.getId();
        if (String.isNotBlank(orderId)) {
            loadOrderData(orderId);
        }
    }
    //Goods_Available__c, Payment_Terms__c, Other_Instructions__c, Terms_and_Conditions__c, Account.TRN__c
    private void loadOrderData(String orderId) {
        try {
            order = [SELECT Id, Name, OrderNumber, CreatedDate, Opportunity.Name, Sales_Rep__r.Name, Discounted_Amount__c,
                     Total_Price__c, VAT__c, Tax_Amount__c, Grand_Total__c, Account.Phone, Branch__r.Name, Payment_Terms__c,
                     Account.ShippingAddress, Account.ShippingStreet, Account.ShippingCity, Discount__c, Good_Available__c, CurrencyIsoCode,
                     Supply_Type__c, Shipping_Method__c, Account.ShippingState, Quote.Email, Branch__r.Branch_Phone__c, Balance_Due__c,
                     Owner.Name, Account.BillingStreet, Account.BillingCity, Account.ShippingCountry, Account.ShippingPostalCode,
                     Account.Name, Account.AccountNumber, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                     Contact__r.Name, Contact__r.Phone, Contact__r.MobilePhone, Contact__r.Email, Branch__r.Branch_Address__c
                     FROM Order 
                     WHERE Id = :orderId 
                     LIMIT 1];
            
            orderProducts = [SELECT Id, Product2.Name, Product2.ProductCode, Gross_Amount__c, CurrencyIsoCode,
                              Description, Quantity, UnitPrice, TotalPrice, Discounted_Price__c, Quantity_SQM__c,
                              Location__c, Product2.Box_s_Per_Pallet__c, Product2.Weight_Per_Box_PCS_Kg__c,
                              Net_Area_Sqm_Lm__c, Unit__c, Discount__c, Product2.Primary_Consumption_Unit__c
                              FROM OrderItem 
                              WHERE OrderId = :order.Id
                             AND (NOT (Product2.Name LIKE '%Discount%'
                                   OR Product2.Name LIKE '%discount%'
                                   OR Description LIKE '%discount%'
                                   OR Description LIKE '%Discount%'))
                              Order By OrderItemNumber ASC];
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                                                       'Error loading quote data: ' + e.getMessage()));
        }
    }
    
    public Decimal getVATPercentage() {
        return 5.0;
    }

}