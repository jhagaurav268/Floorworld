public with sharing class PaymentTriggerHandler implements TriggerInterface {

    public void beforeInsert(List<SObject> newList) {}
    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {}

    public void afterInsert(List<SObject> newList) {
        List<Payment__c> newPayments = (List<Payment__c>) newList;
        CommissionTriggerHelper.processCommissions(newPayments);
    }

    public void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Payment__c> updatedPayments = (List<Payment__c>) newList;
        CommissionTriggerHelper.processCommissions(updatedPayments);
    }

    public void beforeDelete(List<SObject> oldList, Map<Id, SObject> oldMap) {}
    
    public void afterDelete(List<SObject> oldList, Map<Id, SObject> oldMap) {}
}