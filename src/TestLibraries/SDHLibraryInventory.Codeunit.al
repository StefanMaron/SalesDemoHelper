codeunit 75008 "SDH Library - Inventory"
{

    var
        InventorySetup: Record "Inventory Setup";
        LibraryUtility: Codeunit "SDH Library - Utility";
        LibraryERM: Codeunit "SDH Library - ERM";
        JOURNALTxt: Label ' journal';

    procedure PostItemJournalLine(JournalTemplateName: Text[10]; JournalBatchName: Text[10])
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.Init();
        ItemJournalLine.Validate("Journal Template Name", JournalTemplateName);
        ItemJournalLine.Validate("Journal Batch Name", JournalBatchName);
        CODEUNIT.Run(CODEUNIT::"Item Jnl.-Post Batch", ItemJournalLine);
    end;


    procedure CreateItem(var Item: Record Item): Code[20]
    var
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        CreateItemWithoutVAT(Item);

        LibraryERM.FindVATPostingSetupInvt(VATPostingSetup);
        Item.Validate("VAT Prod. Posting Group", VATPostingSetup."VAT Prod. Posting Group");

        Item.Modify(true);
        exit(Item."No.");
    end;

    procedure CreateItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; EntryType: Enum "Item Ledger Entry Type"; PostingDate: Date; ItemNo: Code[20]; Qty: Decimal; LocationCode: Code[10])
    var
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
    begin
        FindItemJournalTemplate(ItemJnlTemplate);
        FindItemJournalBatch(ItemJnlBatch, ItemJnlTemplate);
        CreateItemJournalLine(ItemJnlLine, ItemJnlTemplate.Name, ItemJnlBatch.Name, EntryType, ItemNo, Qty);
        ItemJnlLine."Posting Date" := PostingDate;
        ItemJnlLine."Location Code" := LocationCode;
        ItemJnlLine.Modify();
    end;


    procedure CreateItemJournalLine(var ItemJournalLine: Record "Item Journal Line"; JournalTemplateName: Code[10]; JournalBatchName: Code[10]; EntryType: Enum "Item Ledger Entry Type"; ItemNo: Text[20]; NewQuantity: Decimal)
    var
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        if not ItemJournalBatch.Get(JournalTemplateName, JournalBatchName) then begin
            ItemJournalBatch.Init();
            ItemJournalBatch.Validate("Journal Template Name", JournalTemplateName);
            ItemJournalBatch.SetupNewBatch();
            ItemJournalBatch.Validate(Name, JournalBatchName);
            ItemJournalBatch.Validate(Description, JournalBatchName + JOURNALTxt);
            ItemJournalBatch.Insert(true);
        end;
        CreateItemJnlLineWithNoItem(ItemJournalLine, ItemJournalBatch, JournalTemplateName, JournalBatchName, EntryType);
        ItemJournalLine.Validate("Item No.", ItemNo);
        ItemJournalLine.Validate(Quantity, NewQuantity);
        ItemJournalLine.Modify(true);
    end;

    procedure CreateItemJnlLineWithNoItem(var ItemJournalLine: Record "Item Journal Line"; ItemJournalBatch: Record "Item Journal Batch"; JournalTemplateName: Code[10]; JournalBatchName: Code[10]; EntryType: Enum "Item Ledger Entry Type")
    var
        NoSeries: Record "No. Series";
        NoSeriesCodeunit: Codeunit "No. Series";
        RecRef: RecordRef;
        DocumentNo: Code[20];
    begin
        Clear(ItemJournalLine);
        ItemJournalLine.Init();
        ItemJournalLine.Validate("Journal Template Name", JournalTemplateName);
        ItemJournalLine.Validate("Journal Batch Name", JournalBatchName);
        RecRef.GetTable(ItemJournalLine);
        ItemJournalLine.Validate("Line No.", LibraryUtility.GetNewLineNo(RecRef, ItemJournalLine.FieldNo("Line No.")));
        ItemJournalLine.Insert(true);
        ItemJournalLine.Validate("Posting Date", WorkDate());
        ItemJournalLine.Validate("Entry Type", EntryType);
        if NoSeries.Get(ItemJournalBatch."No. Series") then
            DocumentNo := NoSeriesCodeunit.PeekNextNo(ItemJournalBatch."No. Series", ItemJournalLine."Posting Date")
        else
            DocumentNo := LibraryUtility.GenerateRandomCode(ItemJournalLine.FieldNo("Document No."), DATABASE::"Item Journal Line");
        ItemJournalLine.Validate("Document No.", DocumentNo);
        ItemJournalLine.Modify(true);
    end;

    procedure FindItemJournalTemplate(var ItemJournalTemplate: Record "Item Journal Template")
    begin
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Item);
        ItemJournalTemplate.SetRange(Recurring, false);
        if not ItemJournalTemplate.FindFirst() then begin
            CreateItemJournalTemplate(ItemJournalTemplate);
            ItemJournalTemplate.Validate(Type, ItemJournalTemplate.Type::Item);
            ItemJournalTemplate.Modify(true);
        end;
    end;

    procedure FindItemJournalBatch(var ItemJnlBatch: Record "Item Journal Batch"; ItemJnlTemplate: Record "Item Journal Template")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        ItemJnlBatch.SetRange("Template Type", ItemJnlTemplate.Type);
        ItemJnlBatch.SetRange("Journal Template Name", ItemJnlTemplate.Name);

        if not ItemJnlBatch.FindFirst() then
            CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);

        if ItemJnlBatch."No. Series" = '' then begin
            LibraryUtility.CreateNoSeries(NoSeries, true, false, false);
            LibraryUtility.CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, '', '');
            ItemJnlBatch."No. Series" := NoSeries.Code;
        end;
    end;


    procedure CreateItemJournalBatch(var ItemJournalBatch: Record "Item Journal Batch"; ItemJournalTemplateName: Code[10])
    begin
        // Create Item Journal Batch with a random Name of String length less than 10.
        ItemJournalBatch.Init();
        ItemJournalBatch.Validate("Journal Template Name", ItemJournalTemplateName);
        ItemJournalBatch.Validate(
          Name, CopyStr(LibraryUtility.GenerateRandomCode(ItemJournalBatch.FieldNo(Name), DATABASE::"Item Journal Batch"), 1,
            MaxStrLen(ItemJournalBatch.Name)));
        ItemJournalBatch.Insert(true);
    end;

    procedure CreateItemJournalTemplate(var ItemJournalTemplate: Record "Item Journal Template")
    begin
        ItemJournalTemplate.Init();
        ItemJournalTemplate.Validate(
          Name,
          CopyStr(
            LibraryUtility.GenerateRandomCode(ItemJournalTemplate.FieldNo(Name), DATABASE::"Item Journal Template"),
            1,
            LibraryUtility.GetFieldLength(DATABASE::"Item Journal Template", ItemJournalTemplate.FieldNo(Name))));
        ItemJournalTemplate.Validate(Description, ItemJournalTemplate.Name);
        // Validating Name as Description because value is not important.
        ItemJournalTemplate.Insert(true);
    end;

    procedure CreateItemWithoutVAT(var Item: Record Item)
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        GeneralPostingSetup: Record "General Posting Setup";
        InventoryPostingGroup: Record "Inventory Posting Group";
        TaxGroup: Record "Tax Group";
    begin
        ItemNoSeriesSetup(InventorySetup);
        Clear(Item);
        Item.Insert(true);

        CreateItemUnitOfMeasure(ItemUnitOfMeasure, Item."No.", '', 1);
        LibraryERM.FindGeneralPostingSetupInvtFull(GeneralPostingSetup);

        if not InventoryPostingGroup.FindFirst() then
            CreateInventoryPostingGroup(InventoryPostingGroup);

        Item.Validate(Description, Item."No.");  // Validation Description as No. because value is not important.
        Item.Validate("Base Unit of Measure", ItemUnitOfMeasure.Code);
        Item.Validate("Gen. Prod. Posting Group", GeneralPostingSetup."Gen. Prod. Posting Group");
        Item.Validate("Inventory Posting Group", InventoryPostingGroup.Code);

        if TaxGroup.FindFirst() then
            Item.Validate("Tax Group Code", TaxGroup.Code);

        Item.Modify(true);
    end;

    procedure CreateInventoryPostingGroup(var InventoryPostingGroup: Record "Inventory Posting Group")
    begin
        Clear(InventoryPostingGroup);
        InventoryPostingGroup.Init();
        InventoryPostingGroup.Validate(Code,
          LibraryUtility.GenerateRandomCode(InventoryPostingGroup.FieldNo(Code), DATABASE::"Inventory Posting Group"));
        InventoryPostingGroup.Validate(Description, InventoryPostingGroup.Code);
        InventoryPostingGroup.Insert(true);
    end;

    local procedure ItemNoSeriesSetup(var InventorySetup2: Record "Inventory Setup")
    var
        NoSeriesCode: Code[20];
    begin
        InventorySetup2.Get();
        NoSeriesCode := LibraryUtility.GetGlobalNoSeriesCode();
        if NoSeriesCode <> InventorySetup2."Item Nos." then begin
            InventorySetup2.Validate("Item Nos.", LibraryUtility.GetGlobalNoSeriesCode());
            InventorySetup2.Modify(true);
        end;
    end;

    procedure CreateItemUnitOfMeasure(var ItemUnitOfMeasure: Record "Item Unit of Measure"; ItemNo: Code[20]; UnitOfMeasureCode: Code[10]; QtyPerUoM: Decimal)
    begin
        CreateItemUnitOfMeasure(ItemUnitOfMeasure, ItemNo, UnitOfMeasureCode, QtyPerUoM, 0);
    end;

    procedure CreateItemUnitOfMeasure(var ItemUnitOfMeasure: Record "Item Unit of Measure"; ItemNo: Code[20]; UnitOfMeasureCode: Code[10]; QtyPerUoM: Decimal; QtyRndPrecision: Decimal)
    var
        UnitOfMeasure: Record "Unit of Measure";
    begin
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure.Validate("Item No.", ItemNo);

        // The IF condition is important because it grants flexibility to the function.
        if UnitOfMeasureCode = '' then begin
            UnitOfMeasure.SetFilter(Code, '<>%1', UnitOfMeasureCode);
            UnitOfMeasure.FindFirst();
            ItemUnitOfMeasure.Validate(Code, UnitOfMeasure.Code);
        end else
            ItemUnitOfMeasure.Validate(Code, UnitOfMeasureCode);
        if QtyPerUoM = 0 then
            QtyPerUoM := 1;
        ItemUnitOfMeasure.Validate("Qty. per Unit of Measure", QtyPerUoM);

        if QtyRndPrecision <> 0 then
            ItemUnitOfMeasure.Validate("Qty. Rounding Precision", QtyRndPrecision);
        ItemUnitOfMeasure.Insert(true);
    end;


}