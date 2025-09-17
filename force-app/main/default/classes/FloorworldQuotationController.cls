public class FloorworldQuotationController {
    
    public QuotationData quotation { get; set; }
    
    public FloorworldQuotationController() {
        // Initialize with dummy data
        initializeDummyData();
    }
    
    private void initializeDummyData() {
        quotation = new QuotationData();
        
        // Basic quotation info
        quotation.quotationNumber = 'FW-2025-001234';
        quotation.quotationDate = Date.today();
        quotation.validityDate = Date.today().addDays(30);
        
        // Customer information
        quotation.customerName = 'Al Mansouri Construction LLC';
        quotation.customerId = 'CUST-2025-0456';
        quotation.contactName = 'Ahmed Al Mansouri';
        quotation.mobileNumber = '+971 50 123 4567';
        quotation.email = 'ahmed@almansouri.ae';
        
        // Project details
        quotation.projectName = 'Villa Renovation - Arabian Ranches';
        quotation.salesPerson = 'Sarah Johnson';
        quotation.billingAddress = 'Al Mansouri Construction LLC\nP.O. Box 12345\nDubai, UAE\nPhone: +971 4 123 4567';
        
        // Project specifications
        quotation.supplyType = 'Supply & Installation';
        quotation.goodAvailable = 'Ex-Stock';
        quotation.paymentTerms = '50% Advance, 50% on Completion';
        
        // Initialize product items
        quotation.productItems = new List<QuotationItem>();
        quotation.productItems.add(new QuotationItem(
            1, 'Living Room', 'ENG-OAK-001', 'Engineered Oak Flooring 15mm Natural', 
            8.5, 120, 'Sqm', 85.00, 10200.00
        ));
        quotation.productItems.add(new QuotationItem(
            2, 'Master Bedroom', 'ENG-WAL-002', 'Engineered Walnut Flooring 15mm Dark', 
            6.0, 85, 'Sqm', 95.00, 8075.00
        ));
        quotation.productItems.add(new QuotationItem(
            3, 'Guest Bedrooms', 'LAM-OAK-003', 'Laminate Oak Flooring 8mm AC4', 
            4.2, 65, 'Sqm', 45.00, 2925.00
        ));
        quotation.productItems.add(new QuotationItem(
            4, 'All Areas', 'ACC-SKIRT-001', 'MDF Skirting 18x80mm White Primed', 
            0.0, 150, 'Lm', 12.50, 1875.00
        ));
        
        // Calculate product subtotal
        quotation.productSubtotal = 0;
        for (QuotationItem item : quotation.productItems) {
            quotation.productSubtotal += item.amount;
        }
        
        // Initialize installation items
        quotation.installationItems = new List<QuotationItem>();
        quotation.installationItems.add(new QuotationItem(
            5, 'Living Room', 'INST-ENG-001', 'Installation of Engineered Flooring', 
            0.0, 120, 'Sqm', 25.00, 3000.00
        ));
        quotation.installationItems.add(new QuotationItem(
            6, 'Master Bedroom', 'INST-ENG-002', 'Installation of Engineered Flooring', 
            0.0, 85, 'Sqm', 25.00, 2125.00
        ));
        quotation.installationItems.add(new QuotationItem(
            7, 'Guest Bedrooms', 'INST-LAM-001', 'Installation of Laminate Flooring', 
            0.0, 65, 'Sqm', 18.00, 1170.00
        ));
        quotation.installationItems.add(new QuotationItem(
            8, 'All Areas', 'INST-SKIRT-001', 'Installation of Skirting', 
            0.0, 150, 'Lm', 8.00, 1200.00
        ));
        
        // Calculate installation subtotal
        quotation.installationSubtotal = 0;
        for (QuotationItem item : quotation.installationItems) {
            quotation.installationSubtotal += item.amount;
        }
        
        // Calculate totals
        quotation.total = quotation.productSubtotal + quotation.installationSubtotal;
        quotation.discountAmount = quotation.total * 0.05; // 5% discount
        quotation.taxableAmount = quotation.total - quotation.discountAmount;
        quotation.taxAmount = quotation.taxableAmount * 0.05; // 5% VAT
        quotation.grandTotal = quotation.taxableAmount + quotation.taxAmount;
        
        // Convert amount to words
        quotation.totalInWords = convertAmountToWords(quotation.grandTotal);
    }
    
    // Helper method to convert amount to words (simplified version)
    private String convertAmountToWords(Decimal amount) {
        Integer wholePart = Integer.valueOf(amount);
        Integer decimalPart = Integer.valueOf((amount - wholePart) * 100);
        
        // Simplified conversion - you'd want a more comprehensive implementation
        String[] thousands = new String[]{'', 'Thousand', 'Million', 'Billion'};
        String[] ones = new String[]{'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
                                     'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 
                                     'Seventeen', 'Eighteen', 'Nineteen'};
        String[] tens = new String[]{'', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
        
        if (wholePart == 0) return 'Zero Dirhams Only';
        
        String result = 'Thirty Two Thousand Four Hundred Seventy Five Dirhams'; // Placeholder
        if (decimalPart > 0) {
            result += ' and ' + String.valueOf(decimalPart) + ' Fils';
        }
        result += ' Only';
        
        return result;
    }
    
    // Inner classes for data structure
    public class QuotationData {
        public String quotationNumber { get; set; }
        public Date quotationDate { get; set; }
        public Date validityDate { get; set; }
        
        public String customerName { get; set; }
        public String customerId { get; set; }
        public String contactName { get; set; }
        public String mobileNumber { get; set; }
        public String email { get; set; }
        
        public String projectName { get; set; }
        public String salesPerson { get; set; }
        public String billingAddress { get; set; }
        
        public String supplyType { get; set; }
        public String goodAvailable { get; set; }
        public String paymentTerms { get; set; }
        
        public List<QuotationItem> productItems { get; set; }
        public List<QuotationItem> installationItems { get; set; }
        
        public Decimal productSubtotal { get; set; }
        public Decimal installationSubtotal { get; set; }
        public Decimal total { get; set; }
        public Decimal discountAmount { get; set; }
        public Decimal taxableAmount { get; set; }
        public Decimal taxAmount { get; set; }
        public Decimal grandTotal { get; set; }
        
        public String totalInWords { get; set; }
    }
    
    public class QuotationItem {
        public Integer itemNumber { get; set; }
        public String location { get; set; }
        public String productCode { get; set; }
        public String description { get; set; }
        public Decimal pallets { get; set; }
        public Integer mainQuantity { get; set; }
        public String subQuantity { get; set; }
        public Decimal unitRate { get; set; }
        public Decimal amount { get; set; }
        
        public QuotationItem(Integer itemNum, String loc, String prodCode, String descr, 
                           Decimal palletCount, Integer qty, String subQty, Decimal rate, Decimal amt) {
            this.itemNumber = itemNum;
            this.location = loc;
            this.productCode = prodCode;
            this.description = descr;
            this.pallets = palletCount;
            this.mainQuantity = qty;
            this.subQuantity = subQty;
            this.unitRate = rate;
            this.amount = amt;
        }
    }
}