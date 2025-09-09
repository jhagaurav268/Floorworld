import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import sendForSign from '@salesforce/apex/OrderSignController.handleOrderSign';
import { CurrentPageReference } from 'lightning/navigation';

export default class SendOrderForSign extends LightningElement {
    wireRecordId;
    isLoading = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.wireRecordId = currentPageReference.state.recordId;
        }
    }

    connectedCallback() {
        if (this.wireRecordId) {
            this.isLoading = true;
            sendForSign({ orderId: this.wireRecordId })
                .then(() => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Order sent for signature',
                            variant: 'success'
                        })
                    );
                })
                .catch(error => {
                    console.error('Error:', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error sending Order',
                            message: error.body ? error.body.message : error.message,
                            variant: 'error'
                        })
                    );
                })
                .finally(() => {
                    this.isLoading = false;
                    this.dispatchEvent(new CloseActionScreenEvent());
                });
        }
    }
}