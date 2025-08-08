public class InspectionTriggerHandler {
    public static void createWorkOrders(List<Inspection__c> inspections){
        List<WorkType> workTypeList = [SELECT Id, Name FROM WorkType];
        
        Map<String, Id> workTypeMap = new Map<String, Id>();
        
        for (WorkType wt : workTypeList) {
            workTypeMap.put(wt.Name, wt.Id);
        }
        
        List<WorkOrder> workOrderList = new List<WorkOrder>();
        for(Inspection__c ins : inspections){
            WorkOrder wrk = new WorkOrder();
            wrk.WorkTypeId = workTypeMap.get(ins.Inspection_Type__c);
            wrk.Inspection__c = ins.id;
            workOrderList.add(wrk);
        }
        if(workOrderList!=null){
            insert workOrderList;
        }
    }
}