%dw 2.0
output application/java

fun asList(value) =
    if (value is Array) value
    else if (value == null) []
    else [value]

fun child(node, key) =
    if (node is Object) node[key] else null

fun text(value) =
    if (value is Array) text(value[0])
    else if (value == null) ""
    else (value as String)

fun num(value) =
    if (text(value) == "") 0 else (text(value) as Number)

fun dtmValue(heading, qualifier) =
    text(child(child((asList(child(heading, "DTM")) filter (text(child(child($, "C507"), "2005")) == qualifier))[0], "C507"), "2380"))

fun party(heading, qualifier) =
    (asList(child(heading, "NAD")) filter (text(child($, "3035")) == qualifier))[0]

var messages = payload.Messages default {}
var versionKey = (keysOf(messages))[0]
var typeMap = if (versionKey == null) {} else messages[versionKey]
var typeKey = (keysOf(typeMap))[0]
var message = if (typeKey == null) null else (typeMap[typeKey][0] default null)
var heading = child(message, "Heading") default {}
var mappedLines = asList(child(child(message, "Detail"), "LineItem")) map (item) -> do {
    var quantity = num(child(child(child(item, "QTY"), "C186"), "6060"))
    var unitPrice = num(child(child(child(item, "PRI"), "C509"), "5118"))
    ---
    {
        lineNumber: text(child(child(item, "LIN"), "1082")),
        itemId: text(child(child(child(item, "LIN"), "C212"), "7140")),
        quantity: quantity,
        unitPrice: unitPrice,
        lineAmount: quantity * unitPrice
    }
}
var orderDate = dtmValue(heading, "137")
var deliveryDate = dtmValue(heading, "2")
var currency = text(child(child(child(heading, "CUX"), "C504"), "6345"))
var orderTotal = if (isEmpty(mappedLines)) 0 else sum(mappedLines.lineAmount)
var creditLimit = p("rules.creditLimit") as Number
var reasons =
    (if (currency != p("rules.currency")) ["UNSUPPORTED_CURRENCY"] else [])
    ++ (if (!isEmpty(mappedLines filter $.quantity <= 0)) ["INVALID_QUANTITY"] else [])
    ++ (if (!isEmpty(mappedLines filter $.unitPrice <= 0)) ["INVALID_PRICE"] else [])
    ++ (if (orderDate != "" and deliveryDate != "" and deliveryDate < orderDate) ["DELIVERY_BEFORE_ORDER"] else [])
    ++ (if (orderTotal > creditLimit) ["CREDIT_LIMIT_EXCEEDED"] else [])
---
{
    sender: text(child(child(child(message, "Interchange"), "S002"), "0004")),
    receiver: text(child(child(child(message, "Interchange"), "S003"), "0010")),
    messageReference: text(child(message, "Id")),
    poNumber: text(child(child(child(heading, "BGM"), "C106"), "1004")),
    orderDate: orderDate,
    requestedDeliveryDate: deliveryDate,
    buyer: {
        id: text(child(child(party(heading, "BY"), "C082"), "3039")),
        name: text(child(child(party(heading, "BY"), "C080"), "3036"))
    },
    supplier: {
        id: text(child(child(party(heading, "SU"), "C082"), "3039")),
        name: text(child(child(party(heading, "SU"), "C080"), "3036"))
    },
    currency: currency,
    lines: mappedLines,
    orderTotal: orderTotal,
    status: if (isEmpty(reasons)) "ACCEPTED" else "REJECTED",
    reasons: reasons
}
