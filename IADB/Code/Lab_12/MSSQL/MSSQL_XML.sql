USE warehouse;
GO

IF OBJECT_ID('dbo.Report', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Report
    (
        id INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Report PRIMARY KEY CLUSTERED,
        report_xml XML NOT NULL
    );
END
GO


CREATE OR ALTER PROCEDURE dbo.usp_GenerateWarehouseReportXml
    @ReportXml XML OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @generatedAt DATETIME2(0) = SYSDATETIME();

    SELECT @ReportXml =
    (
        SELECT
            CONVERT(VARCHAR(33), @generatedAt, 126) AS [@generatedAt],

            (
                SELECT
                    COUNT(DISTINCT o.order_id) AS [TotalOrders],
                    SUM(ISNULL(o.total_amount, 0)) AS [TotalAmountByOrdersTable],
                    SUM(ISNULL(CAST(oi.quantity AS DECIMAL(19,4)) * p.price, 0)) AS [CalculatedTotalByItems],
                    SUM(ISNULL(oi.quantity, 0)) AS [TotalUnits]
                FROM dbo.orders o
                LEFT JOIN dbo.order_items oi ON oi.order_id = o.order_id
                LEFT JOIN dbo.products p ON p.product_id = oi.product_id
                FOR XML PATH('GlobalTotals'), TYPE
            ),

            (
                SELECT
                    o.order_status AS [@status],
                    COUNT(*) AS [OrdersCount],
                    SUM(ISNULL(o.total_amount, 0)) AS [StatusAmount]
                FROM dbo.orders o
                GROUP BY o.order_status
                FOR XML PATH('StatusSubtotal'), ROOT('StatusSubtotals'), TYPE
            ),

            (
                SELECT
                    o.order_id AS [@id],
                    CONVERT(VARCHAR(33), o.order_date, 126) AS [@orderDate],
                    o.order_status AS [@status],

                    (
                        SELECT
                            SUM(oi.quantity) AS [UnitsInOrder],
                            SUM(CAST(oi.quantity AS DECIMAL(19,4)) * p.price) AS [OrderSubtotal]
                        FROM dbo.order_items oi
                        JOIN dbo.products p ON p.product_id = oi.product_id
                        WHERE oi.order_id = o.order_id
                        FOR XML PATH('OrderTotals'), TYPE
                    ),

                    (
                        SELECT
                            oi.item_id AS [@id],
                            oi.quantity AS [Quantity],
                            p.product_id AS [Product/@id],
                            p.name AS [Product/Name],
                            p.price AS [Product/Price],
                            s.stock_id AS [Stock/@id],
                            s.description AS [Stock/Description]
                        FROM dbo.order_items oi
                        JOIN dbo.products p ON p.product_id = oi.product_id
                        JOIN dbo.stocks s ON s.stock_id = p.stock_id
                        WHERE oi.order_id = o.order_id
                        FOR XML PATH('Item'), ROOT('Items'), TYPE
                    )
                FROM dbo.orders o
                FOR XML PATH('Order'), ROOT('Orders'), TYPE
            )
        FOR XML PATH('WarehouseReport'), TYPE
    );
END
GO


CREATE OR ALTER PROCEDURE dbo.usp_InsertWarehouseReport
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @x XML;
    EXEC dbo.usp_GenerateWarehouseReportXml @ReportXml = @x OUTPUT;

    INSERT INTO dbo.Report (report_xml)
    VALUES (@x);

    SELECT
        CAST(SCOPE_IDENTITY() AS INT) AS inserted_report_id,
        @x AS inserted_xml;
END
GO


IF EXISTS (SELECT 1 FROM sys.xml_indexes WHERE name = N'PXML_Report_report_xml_PATH')
    DROP INDEX PXML_Report_report_xml_PATH ON dbo.Report;
GO
IF EXISTS (SELECT 1 FROM sys.xml_indexes WHERE name = N'PXML_Report_report_xml')
    DROP INDEX PXML_Report_report_xml ON dbo.Report;
GO


CREATE PRIMARY XML INDEX PXML_Report_report_xml
ON dbo.Report(report_xml);
GO

CREATE XML INDEX PXML_Report_report_xml_PATH
ON dbo.Report(report_xml)
USING XML INDEX PXML_Report_report_xml
FOR PATH;
GO



CREATE OR ALTER PROCEDURE dbo.usp_FindInReportXml
    @SearchValue NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AttrMatches AS
    (
        SELECT
            r.report_id AS report_id,
            o.n.value('@id', 'INT') AS order_id,
            o.n.value('@status', 'NVARCHAR(50)') AS order_status,
            CAST(NULL AS NVARCHAR(200)) AS product_name,
            N'Order/@status' AS matched_in
        FROM dbo.Report r
        CROSS APPLY r.report_xml.nodes('/WarehouseReport/Orders/Order') o(n)
        WHERE o.n.value('@status', 'NVARCHAR(50)') = @SearchValue
    ),
    ElemMatches AS
    (
        SELECT
            r.report_id AS report_id,
            o.n.value('@id', 'INT') AS order_id,
            o.n.value('@status', 'NVARCHAR(50)') AS order_status,
            i.n.value('(Product/Name/text())[1]', 'NVARCHAR(200)') AS product_name,
            N'Product/Name' AS matched_in
        FROM dbo.Report r
        CROSS APPLY r.report_xml.nodes('/WarehouseReport/Orders/Order') o(n)
        CROSS APPLY o.n.nodes('Items/Item') i(n)
        WHERE i.n.value('(Product/Name/text())[1]', 'NVARCHAR(200)') = @SearchValue
    )
    SELECT *
    FROM AttrMatches
    UNION ALL
    SELECT *
    FROM ElemMatches
    ORDER BY report_id, order_id, matched_in;
END
GO


EXEC dbo.usp_InsertWarehouseReport;
EXEC dbo.usp_FindInReportXml @SearchValue = N'Created';
EXEC dbo.usp_FindInReportXml @SearchValue = N'Product 20080';


select * from Products;

select * from report;

DECLARE @status NVARCHAR(50) = N'Created';

SELECT r.report_id
FROM dbo.Report AS r
WHERE r.report_xml.exist('/WarehouseReport/Orders/Order[@status=sql:variable("@status")]') = 1;
GO