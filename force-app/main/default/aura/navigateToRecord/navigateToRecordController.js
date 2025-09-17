({
    invoke: function(component, event, helper) {
        var recordId = component.get("v.recordId");
        var navService = component.find("navService");
        
        var pageReference = {
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        };
        
        navService.navigate(pageReference, true);
    }
})