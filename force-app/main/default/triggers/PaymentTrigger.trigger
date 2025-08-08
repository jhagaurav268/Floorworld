/**
@author : Gaurav jha
@createdDate : 02/07/2025
@Description : Trigger on Payment__c Object
*/
trigger PaymentTrigger on Payment__c (after Insert, after update, after delete, before Insert, before update, before delete) {
	if (Floorworld_Utility.ignorePaymentTrigger == false) {
        TriggerFactory.createHandler(Payment__c.sObjectType);
    }
}