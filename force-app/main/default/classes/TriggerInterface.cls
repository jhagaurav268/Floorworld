/**
@author : Gaurav jha
@createdDate : 02/07/2025
@Description : Interface class for trigger factory setup 
*/

public interface TriggerInterface{
    
    void beforeInsert(List<SObject> newlstObj); 
    /**
     * beforeUpdate
     *
     * This method is called for records to be updated during a BEFORE
     * trigger.
     */
    void beforeUpdate(List<SObject> newlstObj, Map<Id,SObject> oldMapObj);

    /**
     * beforeDelete
     *
     * This method is called for records to be deleted during a BEFORE
     * trigger.
     */
    void beforeDelete(List<SObject> oldlstObj,Map<Id,SObject> oldMapObj);

    /**
     * afterInsert
     *
     * This method is called  for records inserted during an AFTER
     * trigger. Always put field validation in the 'After' methods in case another trigger
     * has modified any values. The record is 'read only' by this point.
     */
    void afterInsert(List<SObject> newlstObj);

    /**
     * afterUpdate
     *
     * This method is called for records updated during an AFTER
     * trigger.
     */
    void afterUpdate(List<SObject> newlstObj, Map<Id,SObject> oldMapObj);

    /**
     * afterDelete
     *
     * This method is called for records deleted during an AFTER
     * trigger.
     */
    void afterDelete(List<SObject> oldlstObj,Map<Id,SObject> oldMapObj);

}