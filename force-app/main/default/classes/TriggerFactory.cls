/**
@author : Gaurav jha
@createdDate : 02/07/2025
@Description : Trigger factory setup for trigger bulkifaction and design pattern
*/

public with sharing class TriggerFactory{

    /**
    * Public static method to create and execute a trigger handler
    *
    * Arguments: Schema.sObjectType soType - Object type to process (SObject.sObjectType)
    *
    * 
    */
    public static void createHandler(Schema.sObjectType soType){
        triggerInterface handler = getHandler(soType);
        execute(handler);
    }

    /**
    * private static method to control the execution of the handler
    *
    * Arguments: triggerInterface handler - A Trigger Handler to execute
    */
    private static void execute(triggerInterface handler){

        // Before Trigger
        if (Trigger.isBefore) {
            
            // Iterate through the records to be deleted passing them to the handler.
            if (Trigger.isDelete) {
                handler.beforeDelete(trigger.old,trigger.oldMap);
            }

            // Iterate through the records to be inserted passing them to the handler.
            else if (Trigger.isInsert) {
                handler.beforeInsert(trigger.new);
            }

            // Iterate through the records to be updated passing them to the handler.
            else if (Trigger.isUpdate) {
                handler.beforeUpdate(trigger.new,trigger.oldMap);
            }
        }else {  
            
            // Iterate through the records deleted passing them to the handler.
            if (Trigger.isDelete) {
                handler.afterDelete(trigger.old,trigger.oldMap);
            }

            // Iterate through the records inserted passing them to the handler.
            else if (Trigger.isInsert) {
                handler.afterInsert(trigger.new);
            }

            // Iterate through the records updated passing them to the handler.
            else if (Trigger.isUpdate) {
                handler.afterUpdate(trigger.new,trigger.oldMap);
            }
        }

    }

    /**
    * private static method to get the appropriate handler for the object type.
    * Modify this method to add any additional handlers.
    *
    * Arguments: Schema.sObjectType soType - Object type tolocate (SObject.sObjectType)
    *
    * Returns: triggerInterface - A trigger handler if one exists or null.
	*/
    public static triggerInterface getHandler(Schema.sObjectType soType){
        if (soType == Payment__c.SObjectType)
            return new PaymentTriggerHandler();

        if (soType == ServiceAppointment.SObjectType)
            return new ServiceAppointmentTriggerHandler();
        
        return null; 
    }
}