import { LightningElement, track, api } from 'lwc';
import searchProductItems from '@salesforce/apex/QuoteController.searchProductItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import upsertQuoteLineItems from '@salesforce/apex/QuoteController.upsertQuoteLineItems';
import getExistingQuoteLineItems from '@salesforce/apex/QuoteController.getExistingQuoteLineItems';

const PRODUCT_FAMILIES = {
    WALL_TO_WALL: ['Wall to Wall', 'F.SHEET-VINYL', 'F.ARTIFICIAL GRASS'],
    DECKING: ['F. DECKING', 'Wood Flooring', 'F.LVT']
};

const TAX_RATE = 0.05;
const DISCOUNT_FAMILY = 'Discount';
const INDIVIDUAL_DISCOUNT_PRODUCTS = ['5% Discount', '10% Discount', '15% Discount', '20% Discount'];

export default class FloorWorldCarpetSolution extends LightningElement {
    @api recordId;

    @track tableData = [];
    @track selectedDiscount = '';
    @track rate = '';
    @track filteredProducts = [];
    @track selectedRowIndex = -1;
    @track deletedRowIds = [];

    rowId = 1;
    copyOfSelectedRow = null;
    isLoading = false;
    searchTimeout = null;

    get discountOptions() {
        return [
            { label: 'None', value: '' },
            { label: 'Discount 5%', value: '5' },
            { label: 'Discount 10%', value: '10' },
            { label: 'Discount 15%', value: '15' },
            { label: 'Discount 25%', value: '25' },
        ];
    }

    connectedCallback() {
        this.initializeComponent();
    }

    async initializeComponent() {
        this.isLoading = true;
        try {
            await this.loadExistingQuoteLineItems();
        } catch (error) {
            this.showToast('Error', 'Failed to load existing items', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadExistingQuoteLineItems() {
        try {
            const data = await getExistingQuoteLineItems({ quoteId: this.recordId });
            const existingRows = data.map(item => this.mapItemToTableRow(item));

            const discountRows = existingRows.filter(row => row.family === DISCOUNT_FAMILY);
            const nonDiscountRows = existingRows.filter(row => row.family !== DISCOUNT_FAMILY);

            if (existingRows.length > 0) {
                this.tableData = [...nonDiscountRows, ...discountRows];

                const overallDiscount = discountRows.find(row => row.location === 'Discount');
                if (overallDiscount && overallDiscount.itemInput) {
                    const match = overallDiscount.itemInput.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        this.rate = match[1];
                        this.selectedDiscount = match[1];
                    }
                }
            } else {
                this.tableData = [this.createNewRow()];
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to load items', 'error');
            this.tableData = [this.createNewRow()];
        }
    }

    createNewRow() {
        return {
            id: this.generateRowId(),
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
            family: '',
            selectedItemId: '',
            averageCost: '',
            costPricePerUnit: '',
            costPrice: '',
            isSuggestionsVisible: false,
            editmode: true,
            readmode: false,
            isSelected: false,
            netAreaDisable: false,
            wastageDisable: true,
            lengthDisable: false,
            individualDiscountRow: null,
            discountAppliedFromRow: null,
            productNameDisabled: false,
            rowNumber: null
        };
    }

    mapItemToTableRow(item) {
        const isWallToWall = PRODUCT_FAMILIES.WALL_TO_WALL.includes(item.productFamily);
        const isDecking = PRODUCT_FAMILIES.DECKING.includes(item.productFamily);

        return {
            id: this.generateRowId(),
            salesforceId: item.salesforceId,
            location: item.location || '',
            itemInput: item.productName || '',
            description: item.productDescription || '',
            netArea: this.safeToString(item.netArea),
            wastage: this.safeToString(item.wastage),
            length: this.safeToString(item.length),
            widthM: this.safeToString(item.width),
            totalArea: this.safeToString(item.totalArea),
            quantity: this.safeToString(item.quantity),
            quantitySqm: this.safeToString(item.quantityArea),
            units: item.units || '',
            rate: this.safeToString(item.rate),
            unitPriceSub: this.safeToString(item.unitPrice),
            amount: this.safeToString(item.amount),
            taxAmount: this.safeToString(item.taxAmount),
            grossAmount: this.safeToString(item.grossAmount),
            estExtendedCost: this.safeToString(item.estExtendedCost),
            costEstimateType: item.location === 'Discount' ? 'Discount' : 'Custom',
            estimateType: item.location === 'Discount' ? 'Discount' : 'Custom',
            family: item.family || '',
            selectedItemId: item.productId,
            averageCost: this.safeToString(item.averageCost),
            costPricePerUnit: this.safeToString(item.costPricePerUnit),
            costPrice: this.safeToString(item.costPrice),
            isSuggestionsVisible: false,
            editmode: false,
            readmode: true,
            isSelected: false,
            netAreaDisable: isWallToWall,
            wastageDisable: true,
            lengthDisable: isDecking,
            individualDiscountRow: null,
            discountAppliedFromRow: null,
            productNameDisabled: true,
            rowNumber: item.rowNumber
        };
    }

    generateRowId() {
        return this.rowId++;
    }

    safeToString(value) {
        return value?.toString() || '';
    }

    safeParseFloat(value, defaultValue = 0) {
        const parsed = parseFloat(value);
        return isNaN(parsed) ? defaultValue : parsed;
    }

    handleDiscountChange(event) {
        this.selectedDiscount = event.detail.value;
        this.rate = this.selectedDiscount;
        this.applyOverallDiscount();
    }

    handleRateChange(event) {
        this.rate = event.target.value;
        this.applyOverallDiscount();
    }

    applyOverallDiscount() {
        if (this.rate && this.rate !== '') {
            const discountRate = this.safeParseFloat(this.rate);

            if (discountRate > 0) {
                this.addOverallDiscountRow(discountRate);
                this.showToast('Success', `${discountRate}% overall discount applied successfully!`, 'success');

            }
        } else {
            this.removeOverallDiscountRow();
        }

    }

    addOverallDiscountRow(discountRate) {
        const eligibleRows = this.tableData.filter(row =>
            !(row.family === DISCOUNT_FAMILY && row.location === 'Discount')
        );

        const totalGrossAmount = eligibleRows.reduce((total, row) =>
            total + this.safeParseFloat(row.grossAmount), 0);
        const totalRate = eligibleRows.reduce((total, row) =>
            total + this.safeParseFloat(row.rate), 0);
        const unitPriceSub = eligibleRows.reduce((total, row) =>
            total + this.safeParseFloat(row.unitPriceSub), 0);
        const amount = eligibleRows.reduce((total, row) =>
            total + this.safeParseFloat(row.amount), 0);
        const taxAmount = eligibleRows.reduce((total, row) =>
            total + this.safeParseFloat(row.taxAmount), 0);

        if (totalGrossAmount <= 0) {
            this.showToast('Warning', 'No items available to apply discount. Please add items first.', 'warning');
            return;
        }

        this.removeOverallDiscountRow();

        const discountRow = this.createOverallDiscountRow(discountRate, totalGrossAmount, totalRate, unitPriceSub, amount, taxAmount);

        this.tableData = [...this.tableData, discountRow];
    }

    removeOverallDiscountRow() {
        this.tableData = this.tableData.filter(row =>
            !(row.family === DISCOUNT_FAMILY && row.location === 'Discount')
        );
    }

    createOverallDiscountRow(discountRate, totalGrossAmount, totalRate, unitPriceSub, amount, taxAmount) {
        const discountAmount = (totalGrossAmount * discountRate) / 100;
        const discountRateAmount = (totalRate * discountRate) / 100;
        const discountUnitPrice = (unitPriceSub * discountRate) / 100;
        const discountAmountOnly = (amount * discountRate) / 100;
        const discountTaxAmount = (taxAmount * discountRate) / 100;

        return {
            ...this.createNewRow(),
            location: 'Discount',
            itemInput: `Discount (${discountRate}%)`,
            description: `${discountRate}% discount on total amount`,
            quantity: 1,
            rate: -discountRateAmount.toFixed(2),
            unitPriceSub: -discountUnitPrice.toFixed(2),
            amount: -discountAmountOnly.toFixed(2),
            taxAmount: -discountTaxAmount.toFixed(2),
            grossAmount: -discountAmount.toFixed(2),
            costEstimateType: 'Discount',
            estimateType: 'Discount',
            family: DISCOUNT_FAMILY,
            editmode: false,
            readmode: true,
            netAreaDisable: true,
            lengthDisable: true,
            rowNumber: 9999 // Always at the end
        };
    }

    applyIndividualDiscount(targetRowIndex, discountProduct) {
        const targetRow = this.tableData[targetRowIndex];
        if (!targetRow) return;

        const match = discountProduct.itemInput.match(/(\d+)%/);
        if (!match) return;

        const discountRate = parseInt(match[1]);

        const discountAmount = (this.safeParseFloat(targetRow.grossAmount) * discountRate) / 100;
        const discountRateAmount = (this.safeParseFloat(targetRow.rate) * discountRate) / 100;
        const discountUnitPrice = (this.safeParseFloat(targetRow.unitPriceSub) * discountRate) / 100;
        const discountAmountOnly = (this.safeParseFloat(targetRow.amount) * discountRate) / 100;
        const discountTaxAmount = (this.safeParseFloat(targetRow.taxAmount) * discountRate) / 100;

        const updatedDiscountProduct = {
            ...discountProduct,
            quantity: 1,
            rate: -discountRateAmount.toFixed(2),
            unitPriceSub: -discountUnitPrice.toFixed(2),
            amount: -discountAmountOnly.toFixed(2),
            taxAmount: -discountTaxAmount.toFixed(2),
            grossAmount: -discountAmount.toFixed(2),
            description: `${discountRate}% discount applied to: ${targetRow.itemInput}`,
            editmode: false,
            readmode: true,
            netAreaDisable: true,
            lengthDisable: true
        };

        const discountProductIndex = this.tableData.findIndex(row => row.id === discountProduct.id);

        if (discountProductIndex !== -1) {
            this.tableData[discountProductIndex] = updatedDiscountProduct;

            this.tableData[targetRowIndex] = {
                ...targetRow,
                individualDiscountRow: updatedDiscountProduct.id
            };

            updatedDiscountProduct.discountAppliedFromRow = targetRow.id;

            this.tableData = [...this.tableData];

            this.showToast('Success', `${discountRate}% individual discount applied to ${targetRow.itemInput}!`, 'success');
        }
    }

    recalculateOverallDiscount() {
        if (this.rate && this.rate !== '') {
            this.addOverallDiscountRow(this.safeParseFloat(this.rate));
        }
    }

    recalculateIndividualDiscounts() {
        this.tableData.forEach((row, index) => {
            if (INDIVIDUAL_DISCOUNT_PRODUCTS.includes(row.itemInput) && row.discountAppliedFromRow) {
                const targetRowIndex = this.tableData.findIndex(r => r.id === row.discountAppliedFromRow);
                if (targetRowIndex !== -1) {
                    this.applyIndividualDiscount(targetRowIndex, row);
                }
            }
        });
    }

    handleInputChange(event) {
        const { id: rowId, field } = event.target.dataset;
        const value = event.target.value;

        this.updateTableRow(parseInt(rowId), field, value);
        this.scheduleDiscountRecalculation(field);
    }

    updateTableRow(rowId, field, value) {
        this.tableData = this.tableData.map(row => {
            if (row.id === rowId) {
                const updatedRow = { ...row, [field]: value };
                this.performCalculations(updatedRow, field);
                this.updateFieldStates(updatedRow, field);
                return updatedRow;
            }
            return row;
        });
    }

    scheduleDiscountRecalculation(field) {
        const fieldsToRecalculate = ['amount', 'grossAmount', 'quantity', 'rate', 'unitPriceSub'];
        if (fieldsToRecalculate.includes(field)) {
            setTimeout(() => {
                this.recalculateOverallDiscount();
                this.recalculateIndividualDiscounts();
            }, 100);
        }
    }

    updateFieldStates(row, field) {
        if (field === 'quantity' && !row.units) {
            row.units = 'SqM';
        }

        if (field !== 'length' && row.totalArea) {
            row.wastageDisable = false;
        } else if (!row.totalArea) {
            row.wastageDisable = true;
        }
    }

    performCalculations(row, changedField) {
        const calculations = {
            netArea: () => this.calculateAreaFromDimensions(row),
            wastage: () => this.calculateAreaFromDimensions(row),
            length: () => this.calculateAreaFromDimensions(row)
        };

        if (calculations[changedField]) {
            calculations[changedField]();
        }

        this.calculateQuantities(row);
        this.calculatePricing(row);
        this.calculateCosts(row);
        this.formatNumbers(row);
    }

    calculateAreaFromDimensions(row) {
        if (row.length && row.widthM) {
            row.netArea = (this.safeParseFloat(row.length) * this.safeParseFloat(row.widthM)).toString();
        }
        row.totalArea = this.calculateTotalArea(row.netArea, row.wastage).toString();
    }

    calculateTotalArea(netArea, wastage) {
        if (!netArea) return 0;
        const net = this.safeParseFloat(netArea);
        const waste = this.safeParseFloat(wastage);
        return net + (net * waste / 100);
    }

    calculateQuantities(row) {
        if (row.totalArea && row.units) {
            const totalArea = this.safeParseFloat(row.totalArea);
            const unitValue = this.extractUnitValue(row.units);

            row.quantity = Math.ceil(totalArea / unitValue).toString();
            row.quantitySqm = (this.safeParseFloat(row.quantity) * unitValue).toFixed(2);
        } else if (row.widthM && !row.units && row.totalArea) {
            const totalArea = this.safeParseFloat(row.totalArea);
            const width = this.safeParseFloat(row.widthM);

            row.quantity = Math.ceil(totalArea / width).toString();
            row.quantitySqm = (this.safeParseFloat(row.quantity) * width).toFixed(2);
        }
    }

    calculatePricing(row) {
        const unitPrice = this.safeParseFloat(row.unitPriceSub);

        if (unitPrice > 0) {
            if (row.units) {
                const unitValue = this.extractUnitValue(row.units);
                row.rate = (unitPrice * unitValue).toFixed(2);
            } else if (row.widthM) {
                row.rate = (unitPrice * this.safeParseFloat(row.widthM)).toFixed(2);
            }
        }

        const quantitySqm = this.safeParseFloat(row.quantitySqm);
        const quantity = this.safeParseFloat(row.quantity);
        const rate = this.safeParseFloat(row.rate);

        if (quantitySqm && unitPrice) {
            row.amount = (quantitySqm * unitPrice).toFixed(2);
        } else if (quantity && rate) {
            row.amount = (quantity * rate).toFixed(2);
        }

        const amount = this.safeParseFloat(row.amount);
        if (amount) {
            row.taxAmount = (amount * TAX_RATE).toFixed(2);
            row.grossAmount = (amount * (1 + TAX_RATE)).toFixed(2);
        }
    }

    calculateCosts(row) {
        const averageCost = this.safeParseFloat(row.averageCost);
        const quantity = this.safeParseFloat(row.quantity);
        if (averageCost && quantity) {
            row.estExtendedCost = (averageCost * quantity).toFixed(2);
        }

        const costPricePerUnit = this.safeParseFloat(row.costPricePerUnit);
        if (costPricePerUnit) {
            if (row.widthM) {
                row.costPrice = (this.safeParseFloat(row.widthM) * costPricePerUnit).toFixed(2);
            } else if (row.units) {
                const unitValue = this.extractUnitValue(row.units);
                row.costPrice = (unitValue * costPricePerUnit).toFixed(2);
            }
        }

        if (row.rate && row.quantity) {
            row.costEstimateType = 'Custom';
        }
    }

    formatNumbers(row) {
        const fieldsToFormat = ['totalArea', 'rate', 'amount', 'taxAmount', 'grossAmount', 'estExtendedCost', 'quantitySqm'];
        fieldsToFormat.forEach(field => {
            if (row[field]) {
                row[field] = this.safeParseFloat(row[field]).toFixed(2);
            }
        });
    }

    extractUnitValue(units) {
        if (typeof units === 'string') {
            const match = units.match(/^(\d+(?:\.\d+)?)/);
            return match ? parseFloat(match[1]) : 1;
        }
        return this.safeParseFloat(units, 1);
    }

    handleSearchChange(event) {
        const rowId = parseInt(event.target.dataset.id);
        const searchTerm = event.target.value;

        this.updateRowSearchTerm(rowId, searchTerm);
        this.debouncedSearch(searchTerm);
    }

    updateRowSearchTerm(rowId, searchTerm) {
        this.tableData = this.tableData.map(row =>
            row.id === rowId ? { ...row, itemInput: searchTerm } : row
        );
    }

    debouncedSearch(searchTerm) {
        clearTimeout(this.searchTimeout);

        if (searchTerm.length > 0) {
            this.searchTimeout = setTimeout(() => {
                this.loadProductSuggestions(searchTerm);
            }, 300);
        } else {
            this.filteredProducts = [];
        }
    }

    async loadProductSuggestions(searchKey) {
        try {
            const result = await searchProductItems({ searchKey });
            this.filteredProducts = result || [];
        } catch (error) {
            console.error('Error fetching product suggestions', error);
            this.filteredProducts = [];
        }
    }

    handleProductSelect(event) {
        const productId = event.target.dataset.id;
        const rowIndex = parseInt(event.target.closest('tr').dataset.index);
        const product = this.filteredProducts.find(p => p.Id === productId);

        if (product && this.tableData[rowIndex]) {
            this.applyProductToRow(rowIndex, product);
            this.hideAllSuggestions();
        }
    }

    applyProductToRow(rowIndex, product) {
        const row = { ...this.tableData[rowIndex] };
        const productData = product.Product2;

        if (INDIVIDUAL_DISCOUNT_PRODUCTS.includes(productData.Name)) {
            const prevRow = this.tableData[rowIndex - 1];
            const nextRow = this.tableData[rowIndex + 1];

            if ((prevRow && INDIVIDUAL_DISCOUNT_PRODUCTS.includes(prevRow.itemInput)) || (nextRow && INDIVIDUAL_DISCOUNT_PRODUCTS.includes(nextRow.itemInput))) {
                this.showToast('Error', 'Cannot apply consecutive discounts.', 'error');
                return;
            }
        }

        Object.assign(row, {
            itemInput: productData.Name,
            description: productData.Description || '',
            units: productData.Primary_Sale_Unit__c || '',
            widthM: productData.Width_m__c || '',
            family: productData.Family || '',
            selectedItemId: product.Id,
            unitPriceSub: product.UnitPrice || '',
            averageCost: productData.Average_Cost__c || 0,
            costPricePerUnit: product.Cost_Prize__c || '',
            rate: product.UnitPrice || ''
        });

        this.setFieldStatesForFamily(row);

        this.performCalculations(row, 'productSelect');

        this.tableData = [
            ...this.tableData.slice(0, rowIndex),
            row,
            ...this.tableData.slice(rowIndex + 1)
        ];

        if (INDIVIDUAL_DISCOUNT_PRODUCTS.includes(productData.Name)) {
            const targetRowIndex = rowIndex - 1;
            if (targetRowIndex >= 0) {
                setTimeout(() => {
                    this.applyIndividualDiscount(targetRowIndex, this.tableData[rowIndex]);
                }, 100);
            }
        }
    }

    setFieldStatesForFamily(row) {
        const isWallToWall = PRODUCT_FAMILIES.WALL_TO_WALL.includes(row.family);
        const isDecking = PRODUCT_FAMILIES.DECKING.includes(row.family);

        row.netAreaDisable = isWallToWall;
        row.lengthDisable = isDecking;
    }

    hideAllSuggestions() {
        this.tableData = this.tableData.map(row => ({
            ...row,
            isSuggestionsVisible: false
        }));
        this.filteredProducts = [];
    }

    handleFocus(event) {
        const rowId = parseInt(event.target.dataset.id);
        this.toggleSuggestionVisibility(rowId, true);
    }

    handleBlur(event) {
        const rowId = parseInt(event.target.dataset.id);
        setTimeout(() => {
            this.toggleSuggestionVisibility(rowId, false);
        }, 200);
    }

    toggleSuggestionVisibility(rowId, isVisible) {
        this.tableData = this.tableData.map(row =>
            row.id === rowId ? { ...row, isSuggestionsVisible: isVisible } : row
        );
    }

    handleRowSelection(event) {
        const selectedIndex = parseInt(event.currentTarget.dataset.index);
        this.selectedRowIndex = selectedIndex;

        this.tableData = this.tableData.map((row, index) => ({
            ...row,
            isSelected: index === selectedIndex
        }));
    }

    handleAddRow() {
        if (this.selectedRowIndex === -1) return;

        const selectedRow = this.tableData[this.selectedRowIndex];
        const isEditMode = selectedRow.editmode;
        const nextRow = this.tableData[this.selectedRowIndex + 1];
        const nextRowIndex = this.selectedRowIndex + 1;

        if (nextRow && INDIVIDUAL_DISCOUNT_PRODUCTS.includes(nextRow.itemInput) && this.tableData[nextRowIndex]) {
            this.tableData[nextRowIndex].description = `${nextRow.itemInput} applied to: ${selectedRow.itemInput}`;
            const match = nextRow.itemInput.match(/(\d+)%/);
            if (!match) return;

            const discountRate = parseInt(match[1]);

            this.tableData[nextRowIndex].grossAmount = -(this.safeParseFloat(selectedRow.grossAmount) * discountRate) / 100;
            this.tableData[nextRowIndex].rate = -(this.safeParseFloat(selectedRow.rate) * discountRate) / 100;
            this.tableData[nextRowIndex].unitPriceSub = -(this.safeParseFloat(selectedRow.unitPriceSub) * discountRate) / 100;
            this.tableData[nextRowIndex].amount = -(this.safeParseFloat(selectedRow.amount) * discountRate) / 100;
            this.tableData[nextRowIndex].taxAmount = -(this.safeParseFloat(selectedRow.taxAmount) * discountRate) / 100;

            this.tableData = [...this.tableData];
        }

        this.tableData[this.selectedRowIndex] = {
            ...selectedRow,
            editmode: !isEditMode,
            readmode: isEditMode
        };

        if (!isEditMode) {
            this.copyOfSelectedRow = JSON.parse(JSON.stringify(selectedRow));
        }

        this.tableData = [...this.tableData];

        setTimeout(() => {
            if (this.rate && this.rate !== '') {
                this.recalculateOverallDiscount();
            }
        }, 100);
    }

    handleCancel() {
        if (this.selectedRowIndex === -1 || !this.copyOfSelectedRow) return;

        this.tableData[this.selectedRowIndex] = {
            ...this.copyOfSelectedRow,
            editmode: false,
            readmode: true
        };
        this.tableData = [...this.tableData];
    }

    handleInsert() {
        if (this.selectedRowIndex === -1) return;

        const newRow = this.createNewRow();
        let insertIndex = this.selectedRowIndex + 1;

        const overallDiscountIndex = this.tableData.findIndex(row =>
            row.family === DISCOUNT_FAMILY && row.location === 'Discount'
        );

        if (overallDiscountIndex !== -1 && insertIndex > overallDiscountIndex) {
            insertIndex = overallDiscountIndex;
        }

        this.tableData = [
            ...this.tableData.slice(0, insertIndex).map(row => ({ ...row, isSelected: false })),
            newRow,
            ...this.tableData.slice(insertIndex).map(row => ({ ...row, isSelected: false }))
        ];

        this.selectedRowIndex = insertIndex;
        this.copyOfSelectedRow = JSON.parse(JSON.stringify(newRow));

        setTimeout(() => {
            this.recalculateOverallDiscount();
            this.recalculateIndividualDiscounts();
        }, 100);
    }

    handleRemove() {
        if (this.selectedRowIndex === -1 || this.tableData.length === 1) return;

        const selectedRow = this.tableData[this.selectedRowIndex];
        const nextRow = this.tableData[this.selectedRowIndex + 1];

        if (selectedRow.salesforceId) {
            this.deletedRowIds = [...this.deletedRowIds, selectedRow.salesforceId];
        }
        setTimeout(() => {
            this.recalculateOverallDiscount();
            this.recalculateIndividualDiscounts();
        }, 100);


        if (nextRow &&
            INDIVIDUAL_DISCOUNT_PRODUCTS.includes(nextRow.itemInput) &&
            !INDIVIDUAL_DISCOUNT_PRODUCTS.includes(selectedRow.itemInput)) {
            this.showToast('Error', 'Please remove the discount from this product first.', 'error');
            return;
        }

        // If removing a row that has an individual discount applied, also remove the discount
        if (selectedRow.individualDiscountRow) {
            const discountRowIndex = this.tableData.findIndex(row => row.id === selectedRow.individualDiscountRow);
            if (discountRowIndex !== -1) {
                const discountRow = this.tableData[discountRowIndex];
                if (discountRow.salesforceId) {
                    this.deletedRowIds = [...this.deletedRowIds, discountRow.salesforceId];
                }
                this.tableData.splice(discountRowIndex, 1);

                // Adjust selectedRowIndex if discount was removed before selected row
                if (discountRowIndex < this.selectedRowIndex) {
                    this.selectedRowIndex--;
                }
            }
        }

        if (selectedRow.family === DISCOUNT_FAMILY && selectedRow.location === 'Discount') {
            this.tableData = this.tableData.filter((_, index) => index !== this.selectedRowIndex);
            this.selectedRowIndex = Math.max(0, this.selectedRowIndex - 1);
            this.rate = '';
            this.selectedDiscount = '';
            return;
        }

        if (INDIVIDUAL_DISCOUNT_PRODUCTS.includes(selectedRow.itemInput)) {
            this.tableData = this.tableData.filter((_, index) => index !== this.selectedRowIndex);
            this.selectedRowIndex = Math.max(0, this.selectedRowIndex - 1);
            return;
        }

        this.tableData = this.tableData.filter((_, index) => index !== this.selectedRowIndex);
        this.selectedRowIndex = Math.max(0, this.selectedRowIndex - 1);

    }

    async handleSave() {
        this.isLoading = true;
        try {
            await this.createQuoteLineItemData();
        } catch (error) {
            this.showToast('Error', 'Failed to save items', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async createQuoteLineItemData() {
        // Assign row numbers before saving
        this.assignRowNumbers();

        const dataObj = this.buildQuoteLineItems();
        const totalDiscountAmount = this.calculateOverallDiscountAmount();
        const discountPercent = this.safeParseFloat(this.rate);

        try {
            await upsertQuoteLineItems({
                lineItemsData: dataObj,
                discountPercent,
                discountAmount: totalDiscountAmount,
                deletedRowIds: this.deletedRowIds
            });
            this.showToast('Success', 'Quote Line Items saved successfully!', 'success');
            // Clear deleted row IDs after successful save
            this.deletedRowIds = [];
        } catch (error) {
            throw new Error(error.body?.message || 'Failed to save items');
        }
    }

    assignRowNumbers() {
        let rowNumber = 1;

        // Filter out overall discount rows for numbering
        const nonOverallDiscountRows = this.tableData.filter(row =>
            !(row.family === DISCOUNT_FAMILY && row.location === 'Discount')
        );

        // Assign row numbers to non-overall-discount rows
        nonOverallDiscountRows.forEach(row => {
            row.rowNumber = rowNumber++;
        });

        // Overall discount rows get the highest number to appear at the end
        this.tableData.forEach(row => {
            if (row.family === DISCOUNT_FAMILY && row.location === 'Discount') {
                row.rowNumber = 9999;
            }
        });
    }

    buildQuoteLineItems() {
        return this.tableData.map(product => ({
            salesforceId: product.salesforceId,
            quoteId: this.recordId,
            location: product.location || '',
            productId: product.selectedItemId || '',
            productDescription: product.description || '',
            netArea: this.safeParseFloat(product.netArea),
            wastage: this.safeParseFloat(product.wastage),
            length: product.length || '',
            width: product.widthM || '',
            totalArea: this.safeParseFloat(product.totalArea),
            rate: this.safeParseFloat(product.rate),
            productUnitPrice: this.safeParseFloat(product.unitPriceSub),
            quantity: this.safeParseFloat(product.quantity, 1),
            quantityArea: this.safeParseFloat(product.quantitySqm),
            price: this.safeParseFloat(product.amount),
            taxAmount: this.safeParseFloat(product.taxAmount),
            grossAmount: this.safeParseFloat(product.grossAmount),
            estExtendedCost: this.safeParseFloat(product.estExtendedCost),
            discountPercentage: this.safeParseFloat(product.discount) * -1,
            discountId: product.discountId || '',
            rowId: product.id.toString(),
            units: product.units || '',
            costPrice: product.costPrice || '',
            type: product.family || '',
            isIndividualDiscount: INDIVIDUAL_DISCOUNT_PRODUCTS.includes(product.itemInput),
            discountAppliedFromRow: product.discountAppliedFromRow || null,
            individualDiscountRow: product.individualDiscountRow || null,
            rowNumber: product.rowNumber
        }));
    }

    calculateOverallDiscountAmount() {
        return this.tableData
            .filter(row => row.family === DISCOUNT_FAMILY && row.location === 'Discount' && row.grossAmount)
            .reduce((total, row) => total + Math.abs(this.safeParseFloat(row.grossAmount)), 0);
    }

    showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode
        }));
    }
}