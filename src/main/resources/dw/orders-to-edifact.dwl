%dw 2.0
output application/java

fun asList(value) =
    if (value is Array) value
    else if (value == null) []
    else [value]

fun num(value) =
    if (value is Number) value
    else if (value == null or (value as String) == "") 0
    else value as Number

fun text(value) =
    if (value == null) "" else value as String

var lines = asList(vars.order.lines)
---
{
    Messages: {
        D96A: {
            ORDERS: [{
                Id: text(vars.order.messageReference),
                Interchange: {
                    S001: { "0001": "UNOC", "0002": "3" },
                    S002: { "0004": text(vars.order.sender), "0007": "ZZZ" },
                    S003: { "0010": text(vars.order.receiver), "0007": "ZZZ" },
                    S004: { "0017": text(vars.order.orderDate)[2 to 7], "0019": "0930" },
                    "0020": text(vars.order.messageReference)
                },
                Heading: {
                    BGM: {
                        C002: { "1001": "220" },
                        C106: { "1004": text(vars.order.poNumber) },
                        "1225": "9"
                    },
                    DTM: [
                        { C507: { "2005": "137", "2380": text(vars.order.orderDate), "2379": "102" } },
                        { C507: { "2005": "2", "2380": text(vars.order.requestedDeliveryDate), "2379": "102" } }
                    ],
                    NAD: [
                        {
                            "3035": "BY",
                            C082: { "3039": text(vars.order.buyer.id), "3055": "92" },
                            C080: { "3036": text(vars.order.buyer.name) }
                        },
                        {
                            "3035": "SU",
                            C082: { "3039": text(vars.order.supplier.id), "3055": "92" },
                            C080: { "3036": text(vars.order.supplier.name) }
                        }
                    ],
                    CUX: {
                        C504: { "6347": "2", "6345": text(vars.order.currency), "6343": "9" }
                    }
                },
                Detail: {
                    LineItem: lines map (line) -> {
                        LIN: {
                            "1082": text(line.lineNumber),
                            C212: { "7140": text(line.itemId), "7143": "IN" }
                        },
                        QTY: { C186: { "6063": "21", "6060": text(num(line.quantity)) } },
                        PRI: { C509: { "5125": "AAA", "5118": text(num(line.unitPrice)) } }
                    }
                },
                Summary: {
                    UNS: { "0081": "S" },
                    CNT: { C270: { "6069": "2", "6066": text(sizeOf(lines)) } }
                }
            }]
        }
    }
}
