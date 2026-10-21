%dw 2.0
output application/java

// These keys are verified against the EDIFACT Connector 3.0 D96A ORDERS read output.
// The connector prefixes each segment/group with its EDIFACT schema position.
fun asList(value) =
    if (value is Array) value
    else if (value == null) []
    else [value]

fun text(value) =
    if (value is Array) text(value[0])
    else if (value == null) ""
    else value as String

fun number(value) =
    if (text(value) == "") 0
    else value as Number

fun dateValue(dates, qualifier) =
    text((dates filter ((date) -> text(date.DTM0101) == qualifier))[0].DTM0102)

fun partyValue(parties, qualifier) =
    ((parties filter ((party) -> text(party."0120_NAD".NAD01) == qualifier))[0]."0120_NAD") default {}

var message = (payload.Messages.D96A.ORDERS[0]) default {}
var interchange = message.Interchange default {}
var header = message.Heading default {}
var dates = asList(header."0030_DTM")
var parties = asList(header."0110_Segment_group_2")
var buyer = partyValue(parties, "BY")
var supplier = partyValue(parties, "SU")
var currencyGroup = asList(header."0280_Segment_group_7")[0] default {}
var currency = text(currencyGroup."0290_CUX".CUX0102)
var orderDate = dateValue(dates, "137")
var deliveryDate = dateValue(dates, "2")
var mappedLines = asList(message.Detail."0930_Segment_group_25") map (line) -> do {
    var quantity = ((asList(line."0980_QTY") filter ((qty) -> text(qty.QTY0101) == "21"))[0]) default {}
    var prices = asList(line."1180_Segment_group_28") map ((group) -> group."1190_PRI")
    var price = ((prices filter ((itemPrice) -> text(itemPrice.PRI0101) == "AAA"))[0]) default {}
    var quantityValue = number(quantity.QTY0102)
    var unitPriceValue = number(price.PRI0102)
    ---
    {
        lineNumber: text(line."0940_LIN".LIN01),
        itemId: text(line."0940_LIN".LIN0301),
        quantity: quantityValue,
        unitPrice: unitPriceValue,
        lineAmount: quantityValue * unitPriceValue
    }
}
var orderTotal = if (isEmpty(mappedLines)) 0 else sum(mappedLines.lineAmount)
var creditLimit = p("rules.creditLimit") as Number
var reasons =
    (if (currency != p("rules.currency")) ["UNSUPPORTED_CURRENCY"] else [])
    ++ (if (!isEmpty(mappedLines filter ((line) -> line.quantity <= 0))) ["INVALID_QUANTITY"] else [])
    ++ (if (!isEmpty(mappedLines filter ((line) -> line.unitPrice <= 0))) ["INVALID_PRICE"] else [])
    ++ (if (orderDate != "" and deliveryDate != "" and deliveryDate < orderDate) ["DELIVERY_BEFORE_ORDER"] else [])
    ++ (if (orderTotal > creditLimit) ["CREDIT_LIMIT_EXCEEDED"] else [])
---
{
    sender: text(interchange.UNB0201),
    receiver: text(interchange.UNB0301),
    messageReference: text(message.MessageHeader.UNH01),
    poNumber: text(header."0020_BGM".BGM02),
    orderDate: orderDate,
    requestedDeliveryDate: deliveryDate,
    buyer: {
        id: text(buyer.NAD0201),
        name: text(buyer.NAD0401)
    },
    supplier: {
        id: text(supplier.NAD0201),
        name: text(supplier.NAD0401)
    },
    currency: currency,
    lines: mappedLines,
    orderTotal: orderTotal,
    status: if (isEmpty(reasons)) "ACCEPTED" else "REJECTED",
    reasons: reasons
}
