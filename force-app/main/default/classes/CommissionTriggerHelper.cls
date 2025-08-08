/**
@author : Gaurav jha
@createdDate : 02/07/2025
@LastModifiedDate: 04/07/2025
@Description : Helper class to calculate commission records on Payment trigger (vendor direct and sales rep via metadata)
*/

public with sharing class CommissionTriggerHelper {

    public static void processCommissions(List<Payment__c> payments) {
        try {
            List<Payment__c> validPayments = filterValidPayments(payments);
            if (validPayments.isEmpty()) return;

            Map<String, Commission__c> existingCommissions = getExistingCommissions(validPayments);
            Map<Id, Order> orders = getOrdersWithDetails(validPayments);
            List<Commission__c> newCommissions = new List<Commission__c>();
            Integer currentMonth = System.today().month();

            for (Payment__c p : validPayments) {
                Order ord = orders.get(p.Order__c);
                if (ord == null || ord.Branch__r.Name == null || ord.Net_Discount__c == null) continue;

                Decimal netDiscount = ord.Net_Discount__c;

                if (ord.AccountId != null) {
                    String vendorKey = ord.AccountId + '|' + currentMonth;
                    if (!existingCommissions.containsKey(vendorKey)) {
                        newCommissions.add(buildVendorCommission(p, ord, ord.Vendor_Commission__c));
                    }
                }

                if (ord.Sales_Rep__c != null) {
                    String repKey = ord.Sales_Rep__c + '|' + currentMonth;
                    if (!existingCommissions.containsKey(repKey)) {
                        Commission_Policy__mdt policy = getMatchingPolicy(ord.Branch__r.Name, netDiscount);
                        if (policy != null) {
                            newCommissions.add(buildSalesRepCommission(p, ord, policy, netDiscount));
                        }
                    }
                }
            }

            if (!newCommissions.isEmpty()) {
                insertCommissions(newCommissions);
            }

        } catch (Exception e) {
            HandleCustomException.LogException(e, 'Payment__c');
        }
    }

    private static Commission__c buildVendorCommission(Payment__c p, Order ord, Decimal discount) {
        return new Commission__c(
            Name = ord.Account.Name + ' - Vendor Commission - ' + System.today().format(),
            Order__c = ord.Id,
            Payment__c = p.Id,
            Vendor__c = ord.AccountId,
            Branch__c = ord.Branch__c,
            Commission_Percent__c = discount,
            Commission_Amount__c = (p.Amount__c * discount) / 100,
            Status__c = 'Pending',
            Discount_Slab_Used__c = discount + '%',
            Type__c = 'Vendor'
        );
    }

    private static Commission__c buildSalesRepCommission(Payment__c p, Order ord, Commission_Policy__mdt policy, Decimal discount) {
        return new Commission__c(
            Name = ord.Sales_Rep__r.Name + ' - Sales Rep Commission - ' + System.today().format(),
            Order__c = ord.Id,
            Payment__c = p.Id,
            Sales_Rep__c = ord.Sales_Rep__c,
            Branch__c = ord.Branch__c,
            Commission_Percent__c = policy.Commission__c,
            Commission_Amount__c = (p.Amount__c * policy.Commission__c) / 100,
            Status__c = 'Pending',
            Discount_Slab_Used__c = formatSlabLabel(policy),
            Total_Discount_Used__c = discount,
            Type__c = 'Sales Rep'
        );
    }

    private static Commission_Policy__mdt getMatchingPolicy(String branchName, Decimal discount) {
        if (branchName == null || discount == null) return null;

        for (Commission_Policy__mdt policy : [
            SELECT Commission__c, Min_Discount__c, Max_Discount__c
            FROM Commission_Policy__mdt
            WHERE Branch__c = :branchName
            ORDER BY Min_Discount__c DESC
        ]) {
            if (discount >= policy.Min_Discount__c && discount <= policy.Max_Discount__c) {
                return policy;
            }
        }
        return null;
    }

    private static List<Payment__c> filterValidPayments(List<Payment__c> payments) {
        List<Payment__c> valid = new List<Payment__c>();
        for (Payment__c p : payments) {
            if (p.Status__c == 'Paid' && p.Order__c != null && p.Amount__c != null) {
                valid.add(p);
            }
        }
        return valid;
    }

    private static Map<String, Commission__c> getExistingCommissions(List<Payment__c> payments) {
        Set<Id> paymentIds = new Set<Id>();
        for (Payment__c p : payments) paymentIds.add(p.Id);

        Map<String, Commission__c> existingMap = new Map<String, Commission__c>();
        for (Commission__c c : [
            SELECT Id, Vendor__c, Sales_Rep__c, CreatedDate, Payment__c
            FROM Commission__c
            WHERE Payment__c IN :paymentIds
        ]) {
            String key = (c.Sales_Rep__c != null ? c.Sales_Rep__c : c.Vendor__c) + '|' + c.CreatedDate.month();
            existingMap.put(key, c);
        }
        return existingMap;
    }

    private static Map<Id, Order> getOrdersWithDetails(List<Payment__c> payments) {
        Set<Id> orderIds = new Set<Id>();
        for (Payment__c p : payments) orderIds.add(p.Order__c);

        return new Map<Id, Order>([
            SELECT Id, Branch__c, Branch__r.Name, Net_Discount__c, AccountId, Account.Name, Sales_Rep__c, Sales_Rep__r.Name, Vendor_Commission__c
            FROM Order
            WHERE Id IN :orderIds
        ]);
    }

    private static String formatSlabLabel(Commission_Policy__mdt policy) {
        return policy.Min_Discount__c + '% - ' + policy.Max_Discount__c + '%';
    }

    private static void insertCommissions(List<Commission__c> commissions) {
        Database.SaveResult[] results = Database.insert(commissions, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug('Failed to create commission: ' + results[i].getErrors()[0].getMessage());
            }
        }
    }
}