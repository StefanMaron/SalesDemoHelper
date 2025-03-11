codeunit 75004 "SDH Library - Sales"
{
    procedure CreateSalesHeader(var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type"; CustomerNo: Code[20])
    begin
        SalesHeader.Init();
        SalesHeader.Validate("Document Type", DocumentType);
        SalesHeader.Insert(true);

        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Modify(true);
    end;

    procedure CreateSalesLine(var SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header"; LineType: Enum "Sales Line Type"; ItemNo: Code[20]; Quantity: Decimal)
    begin
        SalesLine.Init();
        SalesLine.Validate("Document Type", SalesHeader."Document Type");
        SalesLine.Validate("Document No.", SalesHeader."No.");
        SalesLine.Validate("Line No.", GetNextLineNo(SalesHeader));
        SalesLine.Insert(true);

        SalesLine.Validate("Type", LineType);
        SalesLine.Validate("No.", ItemNo);
        SalesLine.Validate("Quantity", Quantity);
        SalesLine.Modify(true);
    end;

    procedure ReopenSalesDocument(var SalesHeader: Record "Sales Header")
    var
        ReleaseSalesDoc: Codeunit "Release Sales Document";
    begin
        ReleaseSalesDoc.PerformManualReopen(SalesHeader);
    end;

    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; NewShipReceive: Boolean; NewInvoice: Boolean): Code[20]
    begin
        exit(DoPostSalesDocument(SalesHeader, NewShipReceive, NewInvoice, false));
    end;

    procedure PostSalesDocumentAndEmail(var SalesHeader: Record "Sales Header"; NewShipReceive: Boolean; NewInvoice: Boolean): Code[20]
    begin
        exit(DoPostSalesDocument(SalesHeader, NewShipReceive, NewInvoice, true));
    end;

    local procedure DoPostSalesDocument(var SalesHeader: Record "Sales Header"; NewShipReceive: Boolean; NewInvoice: Boolean; AfterPostSalesDocumentSendAsEmail: Boolean) DocumentNo: Code[20]
    var
        SalesPost: Codeunit "Sales-Post";
        SalesPostPrint: Codeunit "Sales-Post + Print";
        NoSeries: Codeunit "No. Series";
        RecRef: RecordRef;
        FieldRef: FieldRef;
        LibraryUtility: Codeunit "SDH Library - Utility";
        DocumentFieldNo: Integer;
        WrongDocumentTypeErr: Label 'Document type not supported: %1', Locked = true;
    begin
        // Taking name as NewInvoice to avoid conflict with table field name.
        // Post the sales document.
        // Depending on the document type and posting type return the number of the:
        // - sales shipment,
        // - posted sales invoice,
        // - sales return receipt, or
        // - posted credit memo
        SalesHeader.Validate(Ship, NewShipReceive);
        SalesHeader.Validate(Receive, NewShipReceive);
        SalesHeader.Validate(Invoice, NewInvoice);
        SalesPost.SetPostingFlags(SalesHeader);

        case SalesHeader."Document Type" of
            SalesHeader."Document Type"::Invoice, SalesHeader."Document Type"::"Credit Memo":
                if SalesHeader.Invoice and (SalesHeader."Posting No. Series" <> '') then begin
                    if (SalesHeader."Posting No." = '') then
                        SalesHeader."Posting No." := NoSeries.GetNextNo(SalesHeader."Posting No. Series", LibraryUtility.GetNextNoSeriesSalesDate(SalesHeader."Posting No. Series"));
                    DocumentFieldNo := SalesHeader.FieldNo("Last Posting No.");
                end;
            SalesHeader."Document Type"::Order:
                begin
                    if SalesHeader.Ship and (SalesHeader."Shipping No. Series" <> '') then begin
                        if (SalesHeader."Shipping No." = '') then
                            SalesHeader."Shipping No." := NoSeries.GetNextNo(SalesHeader."Shipping No. Series", LibraryUtility.GetNextNoSeriesSalesDate(SalesHeader."Shipping No. Series"));
                        DocumentFieldNo := SalesHeader.FieldNo("Last Shipping No.");
                    end;
                    if SalesHeader.Invoice and (SalesHeader."Posting No. Series" <> '') then begin
                        if (SalesHeader."Posting No." = '') then
                            SalesHeader."Posting No." := NoSeries.GetNextNo(SalesHeader."Posting No. Series", LibraryUtility.GetNextNoSeriesSalesDate(SalesHeader."Posting No. Series"));
                        DocumentFieldNo := SalesHeader.FieldNo("Last Posting No.");
                    end;
                end;
            SalesHeader."Document Type"::"Return Order":
                begin
                    if SalesHeader.Receive and (SalesHeader."Return Receipt No. Series" <> '') then begin
                        if (SalesHeader."Return Receipt No." = '') then
                            SalesHeader."Return Receipt No." := NoSeries.GetNextNo(SalesHeader."Return Receipt No. Series", LibraryUtility.GetNextNoSeriesSalesDate(SalesHeader."Return Receipt No. Series"));
                        DocumentFieldNo := SalesHeader.FieldNo("Last Return Receipt No.");
                    end;
                    if SalesHeader.Invoice and (SalesHeader."Posting No. Series" <> '') then begin
                        if (SalesHeader."Posting No." = '') then
                            SalesHeader."Posting No." := NoSeries.GetNextNo(SalesHeader."Posting No. Series", LibraryUtility.GetNextNoSeriesSalesDate(SalesHeader."Posting No. Series"));
                        DocumentFieldNo := SalesHeader.FieldNo("Last Posting No.");
                    end;
                end;
            else
                Error(StrSubstNo(WrongDocumentTypeErr, SalesHeader."Document Type"));
        end;

        if AfterPostSalesDocumentSendAsEmail then
            SalesPostPrint.PostAndEmail(SalesHeader)
        else
            SalesPost.Run(SalesHeader);

        RecRef.GetTable(SalesHeader);
        FieldRef := RecRef.Field(DocumentFieldNo);
        DocumentNo := FieldRef.Value();
    end;

    local procedure GetNextLineNo(SalesHeader: Record "Sales Header") LineNo: Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetLoadFields("Line No.");
        SalesLine.ReadIsolation(IsolationLevel::ReadUncommitted);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        LineNo := 10000;
        if SalesLine.FindLast() then
            LineNo += SalesLine."Line No.";
    end;
}