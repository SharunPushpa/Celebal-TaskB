-- ========================================
-- FUNCTIONS
-- ========================================

IF OBJECT_ID('dbo.fn_FormatDate_MMDDYYYY', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_FormatDate_MMDDYYYY
GO
CREATE FUNCTION dbo.fn_FormatDate_MMDDYYYY (@dt DATETIME)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN FORMAT(@dt, 'MM/dd/yyyy')
END
GO

IF OBJECT_ID('dbo.fn_FormatDate_YYYYMMDD', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_FormatDate_YYYYMMDD
GO
CREATE FUNCTION dbo.fn_FormatDate_YYYYMMDD (@dt DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    RETURN CONVERT(CHAR(8), @dt, 112)
END
GO

-- ========================================
-- VIEWS
-- ========================================

IF OBJECT_ID('dbo.vwCustomerOrders', 'V') IS NOT NULL
    DROP VIEW dbo.vwCustomerOrders
GO
CREATE VIEW dbo.vwCustomerOrders AS
SELECT 
    c.AccountNumber AS CustomerAccount,
    soh.SalesOrderID AS OrderID,
    soh.OrderDate,
    sod.ProductID,
    p.Name AS ProductName,
    sod.OrderQty AS Quantity,
    sod.UnitPrice,
    sod.UnitPrice * sod.OrderQty AS Total
FROM 
    Sales.SalesOrderHeader soh
JOIN 
    Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN 
    Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN 
    Production.Product p ON p.ProductID = sod.ProductID
GO

IF OBJECT_ID('dbo.vwCustomerOrders_Yesterday', 'V') IS NOT NULL
    DROP VIEW dbo.vwCustomerOrders_Yesterday
GO
CREATE VIEW dbo.vwCustomerOrders_Yesterday AS
SELECT *
FROM dbo.vwCustomerOrders
WHERE CAST(OrderDate AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
GO

IF OBJECT_ID('dbo.MyProducts', 'V') IS NOT NULL
    DROP VIEW dbo.MyProducts
GO
CREATE VIEW dbo.MyProducts AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    p.ListPrice AS UnitPrice,
    p.SafetyStockLevel AS QuantityPerUnit,
    v.Name AS CompanyName,
    pc.Name AS CategoryName
FROM 
    Production.Product p
JOIN 
    Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN 
    Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
JOIN 
    Purchasing.ProductVendor pv ON pv.ProductID = p.ProductID
JOIN 
    Purchasing.Vendor v ON pv.BusinessEntityID = v.BusinessEntityID
WHERE 
    p.DiscontinuedDate IS NULL OR p.DiscontinuedDate IS NULL
GO

-- ========================================
-- STORED PROCEDURES
-- ========================================

IF OBJECT_ID('dbo.InsertOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE dbo.InsertOrderDetails
GO
CREATE PROCEDURE dbo.InsertOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice MONEY = NULL,
    @Quantity INT,
    @Discount FLOAT = 0
AS
BEGIN
    IF @UnitPrice IS NULL
        SELECT @UnitPrice = ListPrice FROM Production.Product WHERE ProductID = @ProductID

    IF @Discount IS NULL
        SET @Discount = 0

    INSERT INTO Sales.SalesOrderDetail (SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount)
    VALUES (@OrderID, @ProductID, @Quantity, @UnitPrice, @Discount)

    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to place the order. Please try again.'
        RETURN
    END
END
GO

IF OBJECT_ID('dbo.UpdateOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE dbo.UpdateOrderDetails
GO
CREATE PROCEDURE dbo.UpdateOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice MONEY = NULL,
    @Quantity INT = NULL,
    @Discount FLOAT = NULL
AS
BEGIN
    UPDATE Sales.SalesOrderDetail
    SET 
        UnitPrice = ISNULL(@UnitPrice, UnitPrice),
        OrderQty = ISNULL(@Quantity, OrderQty),
        UnitPriceDiscount = ISNULL(@Discount, UnitPriceDiscount)
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID
END
GO

IF OBJECT_ID('dbo.GetOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetOrderDetails
GO
CREATE PROCEDURE dbo.GetOrderDetails
    @OrderID INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID)
    BEGIN
        PRINT 'The OrderID ' + CAST(@OrderID AS VARCHAR) + ' does not exist.'
        RETURN
    END

    SELECT * FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID
END
GO

IF OBJECT_ID('dbo.DeleteOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE dbo.DeleteOrderDetails
GO
CREATE PROCEDURE dbo.DeleteOrderDetails
    @OrderID INT,
    @ProductID INT
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM Sales.SalesOrderDetail 
        WHERE SalesOrderID = @OrderID AND ProductID = @ProductID)
    BEGIN
        PRINT 'Invalid parameters.'
        RETURN
    END

    DELETE FROM Sales.SalesOrderDetail 
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID
END
GO

-- ========================================
-- TRIGGERS (FIXED with correct schema)
-- ========================================

-- INSERT Trigger
IF OBJECT_ID('Sales.tr_AuditSalesOrderDetailInsert', 'TR') IS NOT NULL
    DROP TRIGGER Sales.tr_AuditSalesOrderDetailInsert
GO
CREATE TRIGGER Sales.tr_AuditSalesOrderDetailInsert
ON Sales.SalesOrderDetail
AFTER INSERT
AS
BEGIN
    PRINT 'Order placed successfully!'
END
GO

-- UPDATE Trigger
IF OBJECT_ID('Sales.tr_AuditSalesOrderDetailUpdate', 'TR') IS NOT NULL
    DROP TRIGGER Sales.tr_AuditSalesOrderDetailUpdate
GO
CREATE TRIGGER Sales.tr_AuditSalesOrderDetailUpdate
ON Sales.SalesOrderDetail
AFTER UPDATE
AS
BEGIN
    PRINT 'Order updated successfully!'
END
GO

-- DELETE Trigger
IF OBJECT_ID('Sales.tr_AuditSalesOrderDetailDelete', 'TR') IS NOT NULL
    DROP TRIGGER Sales.tr_AuditSalesOrderDetailDelete
GO
CREATE TRIGGER Sales.tr_AuditSalesOrderDetailDelete
ON Sales.SalesOrderDetail
AFTER DELETE
AS
BEGIN
    PRINT 'Order deleted successfully!'
END
GO
