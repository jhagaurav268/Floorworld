import { LightningElement, track, api } from 'lwc';
import searchProductItems from '@salesforce/apex/QuoteController.searchProductItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import upsertQuoteLineItems from '@salesforce/apex/QuoteController.upsertQuoteLineItems';
import getPendingApprovalStatus from '@salesforce/apex/QuoteController.getPendingApprovalStatus';
import getExistingQuoteLineItems from '@salesforce/apex/QuoteController.getExistingQuoteLineItems';

export default class FloorWorldCarpetSolution extends LightningElement {
    @track tableData = [
        {
            id: 1,
            location: '',
            itemInput: '',
            description: '',
            netArea: '',
            wastage: '',
            length: '',
            widthM: '',
            totalArea: '',
            quantity: '',
            quantitySqm: '',
            units: '',
            rate: '',
            unitPriceSub: '',
            amount: '',
            taxAmount: '',
            grossAmount: '',
            estExtendedCost: '',
            costEstimateType: '',
            estimateType: '',
            isSuggestionsVisible: false,
            editmode: true,
            readmode: false,
            family: '',
            selectedItemId: '',
            averageCost: '',
            costPricePerUnit: '',
            costPrice: '',
            netAreaDisable: true,
            wastageDisable: true,
            lengthDisable: true
        }
    ];
    copyOfSelectedRow;
    rowId = 2;
    isProductSelected = false;
    @api recordId;
    @track selectedDiscount = '';
    @track rate = '';
    isLoading = false;

    discountOptions = [
        { label: 'None', value: '' },
        { label: 'Discount 5%', value: '5' },
        { label: 'Discount 10%', value: '10' },
        { label: 'Discount 15%', value: '15' },
        { label: 'Discount 25%', value: '25' },
    ];

    handleDiscountChange(event) {
        this.selectedDiscount = event.detail.value;
        this.rate = this.selectedDiscount;

        if (this.selectedDiscount && this.selectedDiscount !== '') {
            this.addDiscountRow(parseFloat(this.selectedDiscount));
        }
    }

    handleRateChange(event) {
        this.rate = event.target.value;

        if (this.rate && this.rate !== '') {
            this.addDiscountRow(parseFloat(this.rate));
        }
    }

    addDiscountRow(discountRate) {
        // Calculate total gross amount from all existing rows (excluding discount rows)
        let totalGrossAmount = 0;
        this.tableData.forEach(row => {
            if (row.family !== 'Discount' && row.grossAmount) {
                totalGrossAmount += parseFloat(row.grossAmount);
            }
        });

        if (totalGrossAmount <= 0) {
            this.showToast('Warning', 'No items available to apply discount. Please add items first.', 'warning', 'dismissable');
            return;
        }

        // Remove existing discount row if any
        this.tableData = this.tableData.filter(row => row.family !== 'Discount');

        // Calculate discount amount
        const discountAmount = totalGrossAmount * (discountRate / 100);

        // Create discount row
        const discountRow = {
            id: this.rowId++,
            salesforceId: null,
            location: 'Discount',
            itemInput: `Discount (${discountRate}%)`,
            description: `${discountRate}% discount on total amount`,
            netArea: '',
            wastage: '',
            length: '',
            widthM: '',
            totalArea: '',
            quantity: 1,
            quantitySqm: '',
            units: '',
            rate: -discountAmount.toFixed(2), // Negative for discount
            unitPriceSub: -discountAmount.toFixed(2),
            amount: -discountAmount.toFixed(2),
            taxAmount: (-discountAmount * 0.05).toFixed(2), // 5% tax on discount
            grossAmount: (-discountAmount * 1.05).toFixed(2), // Amount + tax
            estExtendedCost: '',
            costEstimateType: 'Discount',
            estimateType: 'Discount',
            isSuggestionsVisible: false,
            editmode: false,
            readmode: true,
            family: 'Discount',
            selectedItemId: '',
            averageCost: '',
            costPricePerUnit: '',
            costPrice: '',
            netAreaDisable: true,
            lengthDisable: true,
            isSelected: false
        };
        this.tableData.push(discountRow);

        this.tableData = [...this.tableData];

        this.showToast('Success', `${discountRate}% discount applied successfully!`, 'success', 'dismissable');
    }

    handleRateChange(event) {
        this.rate = event.target.value;
    }

    connectedCallback() {
        this.isLoading = true;
        this.loadExistingQuoteLineItems();
    }

    loadExistingQuoteLineItems() {
        getExistingQuoteLineItems({ quoteId: this.recordId })
            .then(data => {
                const existingRows = data.map(item => ({
                    id: this.rowId++,
                    salesforceId: item.salesforceId,
                    location: item.location,
                    itemInput: item.productName,
                    description: item.productDescription,
                    netArea: item.netArea?.toString() || '',
                    wastage: item.wastage?.toString() || '',
                    length: item.length?.toString() || '',
                    widthM: item.width?.toString() || '',
                    totalArea: item.totalArea?.toString() || '',
                    quantity: item.quantity?.toString() || '',
                    quantitySqm: item.quantityArea?.toString() || '',
                    units: item.units || '',
                    rate: item.rate?.toString() || '',
                    unitPriceSub: item.unitPrice?.toString() || '',
                    amount: item.amount?.toString() || '',
                    taxAmount: item.taxAmount?.toString() || '',
                    grossAmount: item.grossAmount?.toString() || '',
                    estExtendedCost: item.estExtendedCost?.toString() || '',
                    costEstimateType: 'Custom',
                    estimateType: item.estimateType || '',
                    family: item.family || '',
                    selectedItemId: item.productId,
                    averageCost: item.averageCost?.toString() || '',
                    costPricePerUnit: item.costPricePerUnit?.toString() || '',
                    costPrice: item.costPrice?.toString() || '',
                    isSuggestionsVisible: false,
                    netAreaDisable: (item.productFamily === 'Wall to Wall' || item.productFamily === 'Sheet Vinyl ' || item.productFamily === 'Grass') ? true : false,
                    lengthDisable: (item.productFamily === 'Decking' || item.productFamily === 'Wood Flooring ' || item.productFamily === 'LVT') ? true : false,
                    editmode: false,
                    readmode: true
                }));
                this.tableData = [
                    ...existingRows,
                    // this.createNewRow()
                ];
                console.log('this.tableData ', JSON.stringify(this.tableData));
                console.log('this.tableData length ', this.tableData.length);

                if (this.tableData.length === 0) {
                    this.tableData = [
                        this.createNewRow()
                    ];
                }
                this.isLoading = false;

            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body.message, 'error', 'dismissable');
            });
    }

    createNewRow() {
        return {
            id: this.rowId++,
            salesforceId: null,
            location: '',
            itemInput: '',
            description: '',
            netArea: '',
            wastage: '',
            length: '',
            widthM: '',
            totalArea: '',
            quantity: '',
            quantitySqm: '',
            units: '',
            rate: '',
            unitPriceSub: '',
            amount: '',
            taxAmount: '',
            grossAmount: '',
            estExtendedCost: '',
            costEstimateType: '',
            estimateType: '',
            isSuggestionsVisible: false,
            editmode: true,
            readmode: false,
            family: '',
            selectedItemId: '',
            averageCost: '',
            costPricePerUnit: '',
            costPrice: ''
        };
    }


    calculateTotalArea(netArea, wastage) {
        if (!netArea) return 0;
        const wastageAmount = parseFloat(netArea) * (parseFloat(wastage || 0) / 100);
        return parseFloat(netArea) + wastageAmount;
    }

    calculateQuantity(totalArea, units) {
        if (!totalArea || !units) return 0;
        const unitValue = typeof units === 'string' ? parseFloat(units.split(' ')[0]) : parseFloat(units);
        if (isNaN(unitValue) || unitValue === 0) return 0;
        return Math.ceil(totalArea / unitValue);
    }

    calculateQuantitySqm(quantity, units) {
        if (!quantity || !units) return 0;
        const unitValue = typeof units === 'string' ? parseFloat(units.split(' ')[0]) : parseFloat(units);
        return quantity * unitValue;
    }

    calculateRate(unitPriceSub, units) {
        if (!unitPriceSub || !units) return 0;
        const unitValue = typeof units === 'string' ? parseFloat(units.split(' ')[0]) : parseFloat(units);
        return unitPriceSub * unitValue;
    }

    calculateAmount(quantitySqm, unitPriceSub) {
        if (!quantitySqm || !unitPriceSub) return 0;
        return quantitySqm * unitPriceSub;
    }

    calculateTaxAmount(amount, shippingCost = 0, shippingTaxRate = 0) {
        const taxOnAmount = (parseFloat(amount) || 0) * 0.05;
        const taxOnShipping = (parseFloat(shippingCost) || 0) * (parseFloat(shippingTaxRate) || 0) / 100;
        return taxOnAmount + taxOnShipping;
    }

    calculateGrossAmount(amount, taxAmount) {
        return (parseFloat(amount) || 0) + (parseFloat(taxAmount) || 0);
    }

    calculateEstExtendedCost(averageCost, quantity) {
        return (parseFloat(averageCost) || 0) * (parseFloat(quantity) || 0);
    }

    performCalculations(row, changedField) {
        if (changedField === 'netArea' || changedField === 'wastage') {
            row.totalArea = this.calculateTotalArea(row.netArea, row.wastage);
        }

        if (changedField === 'length' && row.widthM) {
            row.netArea = parseFloat(row.length) * parseFloat(row.widthM);
            row.totalArea = this.calculateTotalArea(row.netArea, row.wastage);
        }

        if (row.totalArea && row.units) {
            row.quantity = this.calculateQuantity(row.totalArea, row.units);
            row.quantitySqm = this.calculateQuantitySqm(row.quantity, row.units);
        }

        if (row.widthM && !row.units && row.totalArea) {
            row.quantity = Math.ceil(parseFloat(row.totalArea) / parseFloat(row.widthM));
            row.quantitySqm = row.quantity * parseFloat(row.widthM);
        }

        if (row.unitPriceSub) {
            if (row.units) {
                row.rate = this.calculateRate(row.unitPriceSub, row.units);
            } else if (row.widthM) {
                row.rate = parseFloat(row.unitPriceSub) * parseFloat(row.widthM);
            }
        }

        if (row.quantitySqm && row.unitPriceSub) {
            row.amount = this.calculateAmount(row.quantitySqm, row.unitPriceSub);
        } else if (row.quantity && row.rate) {
            row.amount = parseFloat(row.quantity) * parseFloat(row.rate);
        }

        if (row.amount) {
            row.taxAmount = this.calculateTaxAmount(row.amount);
            row.grossAmount = this.calculateGrossAmount(row.amount, row.taxAmount);
        }

        if (row.averageCost && row.quantity) {
            row.estExtendedCost = this.calculateEstExtendedCost(row.averageCost, row.quantity);
        }

        if (row.costPricePerUnit) {
            if (row.widthM) {
                row.costPrice = (parseFloat(row.widthM) * parseFloat(row.costPricePerUnit)).toFixed(2);
            } else if (row.units) {
                const unitValue = typeof row.units === 'string' ? parseFloat(row.units.split(' ')[0]) : parseFloat(row.units);
                row.costPrice = (unitValue * parseFloat(row.costPricePerUnit)).toFixed(2);
            }
        }

        if (row.rate && row.quantity) {
            row.costEstimateType = 'Custom';
        }

        if (row.totalArea) row.totalArea = parseFloat(row.totalArea).toFixed(2);
        if (row.rate) row.rate = parseFloat(row.rate).toFixed(2);
        if (row.amount) row.amount = parseFloat(row.amount).toFixed(2);
        if (row.taxAmount) row.taxAmount = parseFloat(row.taxAmount).toFixed(2);
        if (row.grossAmount) row.grossAmount = parseFloat(row.grossAmount).toFixed(2);
        if (row.estExtendedCost) row.estExtendedCost = parseFloat(row.estExtendedCost).toFixed(2);
        if (row.quantitySqm) row.quantitySqm = parseFloat(row.quantitySqm).toFixed(2);
    }

    handleInputChange(event) {
        const rowId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.tableData = this.tableData.map(row => {
            if (row.id == rowId) {
                let updatedRow = { ...row, [field]: value };

                this.performCalculations(updatedRow, field);

                if (field === 'quantity') {
                    updatedRow.units = updatedRow.units || 'SqM';
                }

                if (field !== 'length' && updatedRow.totalArea) {
                    updatedRow.wastageDisable = false;
                } else if (!updatedRow.totalArea) {
                    updatedRow.wastageDisable = true;
                }

                return updatedRow;
            }
            return row;
        });
        if (['amount', 'grossAmount', 'quantity', 'rate', 'unitPriceSub'].includes(field)) {
            setTimeout(() => {
                this.recalculateDiscount();
            }, 100);
        }
    }

    @track selectedRowIndex;
    handleRowSelection(event) {
        console.log('event.target.dataset', event.currentTarget.dataset.index);
        const selectedRowId = parseInt(event.currentTarget.dataset.index, 10);
        console.log('selectedRowId', selectedRowId);
        this.selectedRowIndex = selectedRowId;
        console.log('this.tableData1', this.tableData);
        this.tableData = this.tableData.map((row, index) => {
            return { ...row, isSelected: index === selectedRowId };
        });

        console.log('this.tableData', this.tableData);
    }

    handleBlur(event) {
        const selectedRowId = parseInt(event.target.dataset.id, 10);
        console.log('this.tableData', this.tableData);
    }

    handleAddRow(event) {
        const index = this.selectedRowIndex;
        console.log('index in handle add row', index);
        if (index !== -1) {
            this.tableData[index].editmode = !this.tableData[index].editmode;
            this.tableData[index].readmode = !this.tableData[index].readmode;
        }
        this.copyOfSelectedRow = JSON.parse(JSON.stringify(this.tableData[this.selectedRowIndex]));
        console.log('this.copyOfSelectedRow n ', this.copyOfSelectedRow);
        console.log('this.tableData in ', this.tableData);
    }

    @track filteredProducts = [];
    @track isSuggestionsVisible = false;

    handleSearchChange(event) {
        this.filteredProducts = []
        const rowId = event.target.dataset.id;
        const searchTerm = event.target.value;
        const index = this.tableData.findIndex(row => row.id == rowId);
        if (index !== -1) {
            this.tableData[index].itemInput = searchTerm;
        }

        if (searchTerm.length > 0) {
            this.isSuggestionsVisible = true;
            this.loadProductSuggestions(searchTerm);
        } else {
            this.isSuggestionsVisible = false;
        }
    }

    loadProductSuggestions(searchKey) {
        console.log('searchKey', searchKey);
        searchProductItems({ searchKey })
            .then((result) => {
                console.log('result ', result);
                this.filteredProducts = result;
                console.log(' this.filteredProducts', this.filteredProducts);
            })
            .catch((error) => {
                console.error('Error fetching product suggestions', error);
            });
    }

    handleProductSelect(event) {
        const productName = event.target.innerText;
        console.log('productName', productName);
        const index = event.target.closest('tr').dataset.index;
        console.log('index', index);
        const selProductId = event.target.dataset.id;
        console.log('selProductId', selProductId);
        const prodIndex = this.filteredProducts.findIndex(prod => prod.Id == selProductId);
        console.log('prodIndex', prodIndex);

        if (index !== -1) {
            this.tableData[index].itemInput = productName;
            console.log('this.tableData[index].itemInput', this.tableData[index].itemInput);
            if (prodIndex != -1) {
                const product = this.filteredProducts[prodIndex];
                console.log('this.filteredProducts[prodIndex]', product.Product2.Description);

                this.tableData[index].description = product.Product2.Description;
                this.tableData[index].units = product.Product2.Primary_Sale_Unit__c ? product.Product2.Primary_Sale_Unit__c : '';
                this.tableData[index].widthM = product.Product2.Width_m__c;
                this.tableData[index].family = product.Product2.Family;
                this.tableData[index].selectedItemId = product.Id;
                this.tableData[index].unitPriceSub = product.UnitPrice;
                this.tableData[index].averageCost = product.Product2.Average_Cost__c || 0;
                this.tableData[index].costPricePerUnit = product.Cost_Prize__c;
                this.tableData[index].rate = product.UnitPrice;

                // var isInstallation = false;
                var isDiscount = false;
                console.log('product.UnitPrice ', product.UnitPrice);
                if (this.tableData[index].family && (this.tableData[index].family === 'Wall to Wall' || this.tableData[index].family === 'Sheet Vinyl ' || this.tableData[index].family === 'Grass')) {
                    console.log('Under if');
                    this.tableData[index].lengthDisable = false;
                    this.tableData[index].netAreaDisable = true;
                } else if (this.tableData[index].family && (this.tableData[index].family === 'Decking' || this.tableData[index].family === 'Wood Flooring' || this.tableData[index].family === 'LVT')) {
                    console.log('Under else if');
                    this.tableData[index].netAreaDisable = false;
                    this.tableData[index].lengthDisable = true;
                }

                this.performCalculations(this.tableData[index], 'productSelect');

                console.log(' before this.tableData', this.tableData);
                console.log('this.tableData', this.tableData);
            }
        }
        this.isSuggestionsVisible = false;
        this.isProductSelected = true;
        this.tableData = [...this.tableData];
        console.log('this.tableData ', JSON.stringify(this.tableData));
    }

    addDiscountItem(selectedIndex, discountRate) {
        if (selectedIndex > 0) {
            let foundProduct = false;
            let productItem = null;

            for (let i = selectedIndex - 1; i >= 0; i--) {
                if (this.tableData[i].family === "Product") {
                    foundProduct = true;
                    productItem = this.tableData[i];
                    break;
                }
            }

            if (foundProduct) {
                const discountAmount = parseFloat(productItem.amount) * (discountRate / 100);
                productItem.discountId = this.tableData[selectedIndex].id;
                productItem.discount = discountRate;
                this.tableData[selectedIndex].amount = discountAmount.toFixed(2);
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No "Product" family item found above the selected index. Discount cannot be applied.',
                        variant: 'error'
                    })
                );
            }
        } else {
            console.error('Invalid index or no item above the selected index.');
        }
    }

    handleFocus(event) {
        const rowId = event.target.dataset.id;
        this.toggleSuggestionVisibility(rowId, true);
    }

    handleBlur(event) {
        const rowId = event.target.dataset.id;
        setTimeout(() => {
            this.toggleSuggestionVisibility(rowId, false);
        }, 200);
    }

    toggleSuggestionVisibility(rowId, isVisible) {
        console.log('rowId', rowId);
        this.tableData = this.tableData.map(row =>
            row.id == rowId ? { ...row, isSuggestionsVisible: isVisible } : row
        );
        this.tableData = [...this.tableData];
        console.log('this.tableData', this.tableData);
    }

    handleCancel() {
        console.log('this.copyOfSelectedRow', this.copyOfSelectedRow);
        this.tableData[this.selectedRowIndex] = this.copyOfSelectedRow;
        this.tableData[this.selectedRowIndex].editmode = false;
        this.tableData[this.selectedRowIndex].readmode = true;
    }

    handleClearAll() {
        this.tableData = [];
    }

    handleInsert() {
        const newRow = this.createNewRow();
        let index = this.selectedRowIndex + 1;
        console.log('index', index);

        this.tableData = [
            ...this.tableData.slice(0, index).map(row => ({ ...row, isSelected: false })),
            newRow,
            ...this.tableData.slice(index).map(row => ({ ...row, isSelected: false }))
        ];
        this.selectedRowIndex = index;
        this.copyOfSelectedRow = JSON.parse(JSON.stringify(this.tableData[this.selectedRowIndex]));
        console.log('this.tableData in ', this.tableData);
    }

    handleRemove() {
        if (this.selectedRowIndex > 0) {
            this.tableData.splice(this.selectedRowIndex, 1);
        }
    }

    handleCopyPrevious() {
        if (this.tableData[this.selectedRowIndex]) {
            const previousRow = JSON.parse(JSON.stringify(this.tableData[this.selectedRowIndex]));

            const newRow = {
                ...previousRow,
                id: this.generateNewId(),
                isSelected: true
            };
            let index = this.selectedRowIndex + 1;

            this.tableData = [
                ...this.tableData.slice(0, index).map(row => ({ ...row, isSelected: false })),
                newRow,
                ...this.tableData.slice(index).map(row => ({ ...row, isSelected: false }))
            ];
            this.selectedRowIndex = index;
            this.copyOfSelectedRow = JSON.parse(JSON.stringify(this.tableData[this.selectedRowIndex]));
        } else {
            console.error('No previous row to copy from.');
        }
    }

    generateNewId() {
        return `row-${Math.random().toString(36).substring(2, 9)}`;
    }

    handleSave(event) {
        this.isLoading = true;
        // this.checkPendingApprovalAndCreateItems();
        this.createQuoteLineItemData();
    }

    checkPendingApprovalAndCreateItems() {
        console.log('this.recordId ', this.recordId)
        getPendingApprovalStatus({ quoteId: this.recordId }).then(hasPendingApproval => {
            console.log('hasPendingApproval ', hasPendingApproval);
            if (hasPendingApproval) {
                this.showToast('Warning', 'Unable to create a new Quote Line Item while approval is pending', 'warning', 'dismissable');
                this.dispatchEvent(new CustomEvent('close'));
                return;
            } else {
                this.createQuoteLineItemData();
            }
        }).catch(error => {
            this.showToast('Error', error.body.message, 'error', 'dismissable');
            console.log('error ' + error);
        });
    }

    createQuoteLineItemData() {
        let dataObj = [];
        let totalDiscountAmount = 0;
        this.tableData.forEach(product => {
            if (product.location === 'Discount' && product.amount) {
                totalDiscountAmount += Math.abs(parseFloat(product.amount));
                return;
            }
            dataObj.push({
                salesforceId: product.salesforceId,
                quoteId: this.recordId,
                location: product.location,
                productId: product.selectedItemId,
                productDescription: product.description || '',
                netArea: product.netArea ? Number(product.netArea) : 0,
                wastage: product.wastage ? Number(product.wastage) : 0,
                length: product.length ? product.length + '' : '',
                width: product.widthM ? product.widthM + '' : '',
                totalArea: product.totalArea ? Number(product.totalArea) : 0,
                rate: product.rate ? Number(product.rate) : 0,
                productUnitPrice:
                    product.family !== 'Discount' && product.unitPriceSub
                        ? Number(product.unitPriceSub ?? 0)
                        : product.family === 'Discount' && product.rate
                            ? Number(product.rate ?? 0)
                            : 0,
                quantity: product.quantity || 1,
                quantityArea: product.quantitySqm ? Number(product.quantitySqm) : 0,
                price: Number(product.amount),
                taxAmount: product.taxAmount ? Number(product.taxAmount) : 0,
                grossAmount: product.grossAmount ? Number(product.grossAmount) : 0,
                estExtendedCost: product.estExtendedCost ? Number(product.estExtendedCost) : 0,
                discountPercentage: product.discount ? Number(product.discount * -1) : 0,
                discountId: product.discountId ? product.discountId + '' : '',
                rowId: product.id ? product.id + '' : '',
                units: product.units || '',
                costPrice: product.costPrice,
                type: product.family
            });
        });

        console.log("dataObj ==?> ", JSON.stringify(dataObj));

        const discountPercent = this.rate ? parseFloat(this.rate) : 0;
        upsertQuoteLineItems({ lineItemsData: dataObj, discountPercent: discountPercent, discountAmount: totalDiscountAmount })
            .then(() => {
                this.showToast('Success', 'Quote Line Items created successfully!', 'success', 'dismissable');
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error', 'dismissable');
                this.isLoading = false;
            });
        this.isLoading = false;
    }

    recalculateDiscount() {
        if (this.rate && this.rate !== '') {
            this.addDiscountRow(parseFloat(this.rate));
        }
    }

    showToast(title, message, variant, mode) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: mode
        });
        this.dispatchEvent(evt);
    }
}