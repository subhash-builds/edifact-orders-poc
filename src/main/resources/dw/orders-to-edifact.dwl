%dw 2.0
output application/java

fun asList(value) =
    if (value is Array) value
    else if (value == null) []
    else [value]

fun text(value) =
    if (value == null) "" else value as String

fun num(value) =
    if (value is Number) value
    else if (value == null or text(value) == "") 0
    else value as Number

fun interchangeDate(value) =
    do {
        var digits = text(value)
        ---
        if (sizeOf(digits) >= 8) (digits[2 to 7]) as Number
        else if (sizeOf(digits) == 6) digits as Number
        else 0
    }

var order = vars.order
var lines = asList(order.lines)
---
{
    Messages: {
        D96A: {
            ORDERS: [{
                Id: "ORDERS",
                Interchange: {
                    UNB0101: "UNOC",
                    UNB0102: "3",
                    UNB0201: text(order.sender),
                    UNB0202: "ZZZ",
                    UNB0301: text(order.receiver),
                    UNB0302: "ZZZ",
                    UNB0401: interchangeDate(order.orderDate),
                    UNB0402: 930,
                    UNB05: text(order.messageReference)
                },
                MessageHeader: {
                    UNH01: text(order.messageReference),
                    UNH0201: "ORDERS",
                    UNH0202: "D",
                    UNH0203: "96A",
                    UNH0204: "UN"
                },
                Heading: {
                    "0020_BGM": {
                        BGM0101: "220",
                        BGM02: text(order.poNumber),
                        BGM03: "9"
                    },
                    "0030_DTM": [
                        { DTM0101: "137", DTM0102: text(order.orderDate), DTM0103: "102" },
                        { DTM0101: "2", DTM0102: text(order.requestedDeliveryDate), DTM0103: "102" }
                    ],
                    "0110_Segment_group_2": [
                        {
                            "0120_NAD": {
                                NAD01: "BY",
                                NAD0201: text(order.buyer.id),
                                NAD0203: "92",
                                NAD0401: text(order.buyer.name)
                            }
                        },
                        {
                            "0120_NAD": {
                                NAD01: "SU",
                                NAD0201: text(order.supplier.id),
                                NAD0203: "92",
                                NAD0401: text(order.supplier.name)
                            }
                        }
                    ],
                    "0280_Segment_group_7": [{
                        "0290_CUX": {
                            CUX0101: "2",
                            CUX0102: text(order.currency),
                            CUX0103: "9"
                        }
                    }]
                },
                Detail: {
                    "0930_Segment_group_25": lines map (line) -> {
                        "0940_LIN": {
                            LIN01: num(line.lineNumber),
                            LIN0301: text(line.itemId),
                            LIN0302: "IN"
                        },
                        "0980_QTY": [{
                            QTY0101: "21",
                            QTY0102: num(line.quantity)
                        }],
                        "1180_Segment_group_28": [{
                            "1190_PRI": {
                                PRI0101: "AAA",
                                PRI0102: num(line.unitPrice)
                            }
                        }]
                    }
                },
                Summary: {
                    "2090_UNS": { UNS01: "S" },
                    "2110_CNT": [{
                        CNT0101: "2",
                        CNT0102: sizeOf(lines)
                    }]
                }
            }]
        }
    }
}
