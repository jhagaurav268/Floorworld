import { LightningElement, api, track } from 'lwc';
import checkOut from '@salesforce/apex/WorkOrderController.checkOut';
import checkWorkStepStatus from '@salesforce/apex/WorkOrderController.checkWorkStepStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';


export default class CheckOut extends LightningElement {
    @api recordId;
    @track rating = '';
    @track comment = '';
    @track showComponent = false;
    @track componentMessage;


    @track ratingOptions = [
        { label: '😡 Very Dissatisfied', value: '1' },
        { label: '☹️ Dissatisfied', value: '2' },
        { label: '😐 Neutral', value: '3' },
        { label: '🙂 Satisfied', value: '4' },
        { label: '😁 Very Satisfied', value: '5' }
    ];

    connectedCallback() {
        console.log('this.recordId-->', this.recordId);
        checkWorkStepStatus({ recordId: this.recordId, executionOrder: 4 }).then((result) => {
            console.log('result-->', result);
            if (result != '') {
                this.showComponent = false;
                this.componentMessage = result;
            }
            else {
                this.showComponent = true;
            }
        })
            .catch(error => {
                console.error('Error updating record:', error);
            });
    }


    handleRatingChange(event) {
        this.rating = event.detail.value;
        console.log('this.rating-->', this.rating);
    }

    handleCommentChange(event) {
        this.comment = event.detail.value;
    }

    submitFeedback() {
        if (!this.rating) {
            this.showToast('Error', 'Please select a rating.', 'error');
            return;
        }

        checkOut({ recordId: this.recordId, rating: parseInt(this.rating), comment: this.comment })
            .then(() => {
                this[NavigationMixin.Navigate]({
                    "type": "standard__webPage",
                    "attributes": {
                        "url": `com.salesforce.fieldservice://v1/sObject/${this.recordId}`
                    }
                });

                this.showToast('Success', 'Thank you for your feedback!', 'success');
                this.rating = '';
                this.comment = '';
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', error || 'An error occurred', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}