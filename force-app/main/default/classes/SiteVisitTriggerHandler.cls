public class SiteVisitTriggerHandler {
     public static void createWorkOrders(List<Site_Visit__c> siteVisits){
       List<WorkType> workTypeList = [SELECT Id, Name FROM WorkType];
        
        Map<String, Id> workTypeMap = new Map<String, Id>();
        
        for (WorkType wt : workTypeList) {
            workTypeMap.put(wt.Name, wt.Id);
        }
        
        List<WorkOrder> workOrderList = new List<WorkOrder>();
        for(Site_Visit__c siteVts : siteVisits){
            WorkOrder wrk = new WorkOrder();
            wrk.WorkTypeId = workTypeMap.get(siteVts.Type__c);
            wrk.Site_Visit__c = siteVts.id;
            workOrderList.add(wrk);
        }
        if(workOrderList!=null){
            insert workOrderList;
        }
    }
}