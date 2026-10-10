import calendar
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")
MAX_MONTHS = 1200  # 100 years: hard stop so a bad input can't loop forever


def money(value) -> Decimal:
    return Decimal(value).quantize(CENT, ROUND_HALF_UP)


def add_months(d: date, months: int) -> date:
    y, m = divmod(d.year * 12 + d.month - 1 + months, 12)
    m += 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


def amortize(balance, apr, payment, start: date | None = None) -> dict:
    """Fixed monthly payment schedule. Monthly rate = APR / 12."""
    balance = Decimal(balance)
    payment = Decimal(payment)
    rate = Decimal(apr) / Decimal(1200)

    empty = {
        "payable": True, "months": 0, "total_interest": Decimal("0"),
        "total_paid": Decimal("0"), "payoff_date": start, "schedule": [],
    }
    if balance <= 0:
        return empty

    # If the payment doesn't even cover the first month's interest,
    # the balance never shrinks.
    if payment <= money(balance * rate):
        return {**empty, "payable": False, "months": None, "payoff_date": None}

    schedule, total_interest, total_paid, month = [], Decimal("0"), Decimal("0"), 0
    while balance > 0 and month < MAX_MONTHS:
        month += 1
        interest = money(balance * rate)
        paid = min(payment, balance + interest)
        balance = balance + interest - paid
        total_interest += interest
        total_paid += paid
        schedule.append({
            "month": month, "payment": paid, "interest": interest,
            "principal": paid - interest, "balance": balance,
        })

    if balance > 0:
        return {**empty, "payable": False, "months": None, "payoff_date": None}

    return {
        "payable": True, "months": month, "total_interest": total_interest,
        "total_paid": total_paid,
        "payoff_date": add_months(start, month) if start else None,
        "schedule": schedule,
    }


def payoff_plan(debts: list[dict], extra, strategy: str, start: date | None = None) -> dict:
    """
    Pay minimums on everything, then throw all remaining budget at one debt.
    The budget (sum of minimums + extra) stays constant as debts are cleared,
    so freed-up minimums roll into the next target (the "snowball").

    strategy: "avalanche" (highest APR first) or "snowball" (smallest balance first)
    """
    items = [
        {**d, "balance": Decimal(d["balance"])}
        for d in debts if Decimal(d["balance"]) > 0
    ]
    if not items:
        return {"strategy": strategy, "payable": True, "months": 0,
                "total_interest": Decimal("0"), "payoff_date": start, "payoff_order": []}

    if strategy == "avalanche":
        items.sort(key=lambda d: -Decimal(d["apr"]))
    else:
        items.sort(key=lambda d: d["balance"])

    budget = sum(Decimal(d["minimum_payment"]) for d in items) + Decimal(extra)
    total_interest, month, order = Decimal("0"), 0, []

    while any(d["balance"] > 0 for d in items) and month < MAX_MONTHS:
        month += 1
        for d in items:
            if d["balance"] > 0:
                interest = money(d["balance"] * Decimal(d["apr"]) / Decimal(1200))
                d["balance"] += interest
                total_interest += interest

        remaining = budget
        for d in items:  # minimums first
            if d["balance"] > 0:
                paid = min(Decimal(d["minimum_payment"]), d["balance"], remaining)
                d["balance"] -= paid
                remaining -= paid
        for d in items:  # everything left goes to the highest-priority debt
            if remaining <= 0:
                break
            if d["balance"] > 0:
                paid = min(d["balance"], remaining)
                d["balance"] -= paid
                remaining -= paid

        for d in items:
            if d["balance"] <= 0 and all(o["debt_id"] != d["id"] for o in order):
                order.append({"debt_id": d["id"], "name": d["name"], "month": month})

    payable = all(d["balance"] <= 0 for d in items)
    return {
        "strategy": strategy,
        "payable": payable,
        "months": month if payable else None,
        "total_interest": total_interest if payable else None,
        "payoff_date": add_months(start, month) if (start and payable) else None,
        "payoff_order": order,
    }