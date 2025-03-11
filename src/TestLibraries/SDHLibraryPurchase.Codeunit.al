codeunit 75012 "SDH Library - Purchase"
{
    procedure CreatePurchaseHeader(var PurchaseHeader: Record "Purchase Header"; DocumentType: Enum "Purchase Document Type"; CustomerNo: Code[20])
    begin
        PurchaseHeader.Init();
        PurchaseHeader.Validate("Document Type", DocumentType);
        PurchaseHeader.Insert(true);

        PurchaseHeader.Validate("Sell-to Customer No.", CustomerNo);
        PurchaseHeader.Modify(true);
    end;

    procedure CreatePurchaseLine(var PurchaseLine: Record "Purchase Line"; PurchaseHeader: Record "Purchase Header"; LineType: Enum "Purchase Line Type"; ItemNo: Code[20]; Quantity: Decimal)
    begin
        PurchaseLine.Init();
        PurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.Validate("Document No.", PurchaseHeader."No.");
        PurchaseLine.Validate("Line No.", GetNextLineNo(PurchaseHeader));
        PurchaseLine.Insert(true);

        PurchaseLine.Validate("Type", LineType);
        PurchaseLine.Validate("No.", ItemNo);
        PurchaseLine.Validate("Quantity", Quantity);
        PurchaseLine.Modify(true);
    end;


    procedure CreatePurchaseLineWithUnitCost(var PurchaseLine: Record "Purchase Line"; PurchaseHeader: Record "Purchase Header"; ItemNo: Code[20]; UnitCost: Decimal; Quantity: Decimal)
    begin
        CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, ItemNo, Quantity);
        PurchaseLine.Validate("Direct Unit Cost", UnitCost);
        PurchaseLine.Modify();
    end;

    procedure CreatePurchaseOrderWithLocation(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; LocationCode: Code[10])
    begin
        CreatePurchaseHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, VendorNo);
        PurchaseHeader.Validate("Vendor Invoice No.", PurchaseHeader."No.");
        PurchaseHeader.Validate("Location Code", LocationCode);
        PurchaseHeader.Modify();
    end;

    procedure ReopenPurchaseDocument(var PurchaseHeader: Record "Purchase Header")
    var
        ReleasePurchaseDoc: Codeunit "Release Purchase Document";
    begin
        ReleasePurchaseDoc.PerformManualReopen(PurchaseHeader);
    end;

    procedure PostPurchaseDocument(var PurchaseHeader: Record "Purchase Header"; NewShipReceive: Boolean; NewInvoice: Boolean) DocumentNo: Code[20]
    var
        NoSeries: Codeunit "No. Series";
        PurchPost: Codeunit "Purch.-Post";
        RecRef: RecordRef;
        FieldRef: FieldRef;
        DocumentFieldNo: Integer;
        WrongDocumentTypeErr: Label 'Document type not supported: %1', Locked = true;
        LibraryUtility: Codeunit "SDH Library - Utility";
    begin
        // Post the purchase document.
        // Depending on the document type and posting type return the number of the:
        // - purchase receipt,
        // - posted purchase invoice,
        // - purchase return shipment, or
        // - posted credit memo
        PurchaseHeader.Validate(Receive, NewShipReceive);
        PurchaseHeader.Validate(Ship, NewShipReceive);
        PurchaseHeader.Validate(Invoice, NewInvoice);
        PurchPost.SetPostingFlags(PurchaseHeader);

        case PurchaseHeader."Document Type" of
            PurchaseHeader."Document Type"::Invoice, PurchaseHeader."Document Type"::"Credit Memo":
                if PurchaseHeader.Invoice and (PurchaseHeader."Posting No. Series" <> '') then begin
                    if (PurchaseHeader."Posting No." = '') then
                        PurchaseHeader."Posting No." := NoSeries.GetNextNo(PurchaseHeader."Posting No. Series", LibraryUtility.GetNextNoSeriesPurchaseDate(PurchaseHeader."Posting No. Series"));
                    DocumentFieldNo := PurchaseHeader.FieldNo("Last Posting No.");
                end;
            PurchaseHeader."Document Type"::Order:
                begin
                    if PurchaseHeader.Receive and (PurchaseHeader."Receiving No. Series" <> '') then begin
                        if (PurchaseHeader."Receiving No." = '') then
                            PurchaseHeader."Receiving No." := NoSeries.GetNextNo(PurchaseHeader."Receiving No. Series", LibraryUtility.GetNextNoSeriesPurchaseDate(PurchaseHeader."Receiving No. Series"));
                        DocumentFieldNo := PurchaseHeader.FieldNo("Last Receiving No.");
                    end;
                    if PurchaseHeader.Invoice and (PurchaseHeader."Posting No. Series" <> '') then begin
                        if (PurchaseHeader."Posting No." = '') then
                            PurchaseHeader."Posting No." := NoSeries.GetNextNo(PurchaseHeader."Posting No. Series", LibraryUtility.GetNextNoSeriesPurchaseDate(PurchaseHeader."Posting No. Series"));
                        DocumentFieldNo := PurchaseHeader.FieldNo("Last Posting No.");
                    end;
                end;
            PurchaseHeader."Document Type"::"Return Order":
                begin
                    if PurchaseHeader.Ship and (PurchaseHeader."Return Shipment No. Series" <> '') then begin
                        if (PurchaseHeader."Return Shipment No." = '') then
                            PurchaseHeader."Return Shipment No." := NoSeries.GetNextNo(PurchaseHeader."Return Shipment No. Series", LibraryUtility.GetNextNoSeriesPurchaseDate(PurchaseHeader."Return Shipment No. Series"));
                        DocumentFieldNo := PurchaseHeader.FieldNo("Last Return Shipment No.");
                    end;
                    if PurchaseHeader.Invoice and (PurchaseHeader."Posting No. Series" <> '') then begin
                        if (PurchaseHeader."Posting No." = '') then
                            PurchaseHeader."Posting No." := NoSeries.GetNextNo(PurchaseHeader."Posting No. Series", LibraryUtility.GetNextNoSeriesPurchaseDate(PurchaseHeader."Posting No. Series"));
                        DocumentFieldNo := PurchaseHeader.FieldNo("Last Posting No.");
                    end;
                end;
            else
                Error(StrSubstNo(WrongDocumentTypeErr, PurchaseHeader."Document Type"))
        end;

        CODEUNIT.Run(CODEUNIT::"Purch.-Post", PurchaseHeader);

        RecRef.GetTable(PurchaseHeader);
        FieldRef := RecRef.Field(DocumentFieldNo);
        DocumentNo := FieldRef.Value();
    end;

    local procedure GetNextLineNo(PurchaseHeader: Record "Purchase Header") LineNo: Integer
    var
        PurchaseLine: Record "Purchase Line";
    begin
        PurchaseLine.SetLoadFields("Line No.");
        PurchaseLine.ReadIsolation(IsolationLevel::ReadUncommitted);
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        LineNo := 10000;
        if PurchaseLine.FindLast() then
            LineNo += PurchaseLine."Line No.";
    end;
}