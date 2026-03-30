"""
Receipt PDF generation service.

Uses xhtml2pdf to convert an HTML template (template D) into a PDF byte stream.
"""
import io
import logging
from datetime import datetime

from xhtml2pdf import pisa

logger = logging.getLogger(__name__)


def _currency_symbol(currency: str) -> str:
    return {"GBP": "£", "EUR": "€", "USD": "$", "CNY": "¥"}.get(
        currency.upper(), currency.upper()
    )


def _format_amount(pence: int | None, currency: str) -> str:
    if pence is None or pence == 0:
        return f"{_currency_symbol(currency)}0.00"
    return f"{_currency_symbol(currency)}{pence / 100:.2f}"


def _format_date(dt: datetime | None) -> str:
    if dt is None:
        return ""
    return dt.strftime("%d %b %Y, %H:%M UTC")


def _status_label(status: str) -> str:
    return {
        "succeeded": "Payment Successful",
        "pending": "Pending",
        "failed": "Failed",
        "canceled": "Canceled",
    }.get(status, status)


def _status_color(status: str) -> str:
    return {
        "succeeded": "#16A34A",
        "pending": "#D97706",
        "failed": "#DC2626",
        "canceled": "#DC2626",
    }.get(status, "#888")


def _method_label(method: str | None) -> str:
    return {
        "stripe": "Stripe",
        "alipay": "Alipay via Stripe",
        "wechat_pay": "WeChat Pay via Stripe",
        "wallet": "Wallet Balance",
        "coupon": "Coupon",
        "mixed": "Wallet + Stripe",
        "points_only": "Points",
    }.get((method or "stripe").lower(), method or "Stripe")


def _task_type_label(task_source: str | None) -> str:
    return {
        "flea_market": "Flea Market",
        "normal": "Task",
        "rental": "Rental",
    }.get(task_source or "normal", task_source or "Task")


# ---------------------------------------------------------------------------
# HTML template (based on template D mobile)
# ---------------------------------------------------------------------------

_RECEIPT_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<style>
  @page {{ size: A4; margin: 20mm; }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: Helvetica, Arial, sans-serif;
    color: #333;
    font-size: 12px;
    line-height: 1.5;
  }}
  .receipt {{ max-width: 480px; margin: 0 auto; padding: 16px 0; }}

  .header {{
    display: block;
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 2px solid #4A9E6B;
  }}
  .brand-name {{
    font-size: 18px;
    font-weight: bold;
    color: #1A1A2E;
  }}
  .brand-name span {{ color: #4A9E6B; }}
  .receipt-label {{
    font-size: 10px;
    color: #999;
    text-transform: uppercase;
    letter-spacing: 1px;
    float: right;
    margin-top: 4px;
  }}

  .hero {{
    background: #F2F9F5;
    border-radius: 8px;
    padding: 14px;
    margin-bottom: 14px;
  }}
  .hero-status {{
    font-size: 12px;
    font-weight: bold;
    color: {status_color};
    margin-bottom: 2px;
  }}
  .hero-date {{ font-size: 10px; color: #999; }}
  .hero-amount {{
    font-size: 24px;
    font-weight: bold;
    color: #1A1A2E;
    text-align: right;
    margin-top: -28px;
  }}
  .hero-amount .currency {{ font-size: 16px; color: #4A9E6B; }}

  .section {{
    border: 1px solid #E4F0E9;
    border-radius: 8px;
    margin-bottom: 10px;
    padding: 10px 12px;
  }}
  .section-title {{
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #4A9E6B;
    font-weight: bold;
    margin-bottom: 8px;
  }}
  .row {{
    padding: 4px 0;
    border-bottom: 1px solid #EDF5F0;
  }}
  .row:last-child {{ border-bottom: none; }}
  .row-label {{
    font-size: 11px;
    color: #888;
    display: inline-block;
    width: 40%;
  }}
  .row-value {{
    font-size: 11px;
    color: #333;
    font-weight: bold;
    display: inline-block;
    width: 58%;
    text-align: right;
  }}

  .bk-row {{ padding: 4px 0; }}
  .bk-label {{ display: inline-block; width: 60%; font-size: 11px; color: #666; }}
  .bk-val {{ display: inline-block; width: 38%; text-align: right; font-size: 11px; color: #666; }}
  .bk-discount .bk-val {{ color: #16A34A; }}
  .bk-total {{
    border-top: 1.5px solid #D4E6DA;
    margin-top: 4px;
    padding-top: 8px;
    font-weight: bold;
    font-size: 13px;
    color: #1A1A2E;
  }}

  .footer {{
    text-align: center;
    padding-top: 14px;
    border-top: 1px solid #F0F0F0;
    margin-top: 8px;
    font-size: 9px;
    color: #ccc;
    line-height: 1.8;
  }}
  .footer a {{ color: #4A9E6B; text-decoration: none; }}
</style>
</head>
<body>
  <div class="receipt">
    <div class="header">
      <span class="receipt-label">Receipt</span>
      <div class="brand-name">Link<span>2Ur</span></div>
    </div>

    <div class="hero">
      <div class="hero-status">{status_label}</div>
      <div class="hero-date">{date}</div>
      <div class="hero-amount"><span class="currency">{symbol}</span>{amount_display}</div>
    </div>

    <div class="section">
      <div class="section-title">Order</div>
      <div class="row">
        <span class="row-label">Order No.</span>
        <span class="row-value">{order_no}</span>
      </div>
      <div class="row">
        <span class="row-label">Payment</span>
        <span class="row-value">{payment_method}</span>
      </div>
    </div>

    <div class="section">
      <div class="section-title">Item</div>
      <div class="row">
        <span class="row-label">Name</span>
        <span class="row-value">{task_title}</span>
      </div>
      <div class="row">
        <span class="row-label">Type</span>
        <span class="row-value">{task_type}</span>
      </div>
      {counterpart_row}
    </div>

    <div class="section">
      <div class="section-title">Breakdown</div>
      <div class="bk-row">
        <span class="bk-label">Subtotal</span>
        <span class="bk-val">{total_amount}</span>
      </div>
      {coupon_row}
      {points_row}
      <div class="bk-row bk-total">
        <span class="bk-label">Total Paid</span>
        <span class="bk-val">{final_amount}</span>
      </div>
    </div>

    <div class="footer">
      <p><a href="https://www.link2ur.com">Link2Ur</a> &middot; support@link2ur.com</p>
      <p>Electronic receipt &middot; No signature required</p>
    </div>
  </div>
</body>
</html>"""


def generate_receipt_pdf(payment, task, counterpart_name: str | None) -> bytes:
    """Generate a receipt PDF for a payment record. Returns PDF bytes."""
    currency = payment.currency or "GBP"
    symbol = _currency_symbol(currency)

    # Conditional rows
    counterpart_row = ""
    if counterpart_name:
        counterpart_row = (
            f'<div class="row">'
            f'<span class="row-label">Seller</span>'
            f'<span class="row-value">{counterpart_name}</span>'
            f'</div>'
        )

    coupon_row = ""
    if payment.coupon_discount and payment.coupon_discount > 0:
        coupon_row = (
            f'<div class="bk-row bk-discount">'
            f'<span class="bk-label">Coupon Discount</span>'
            f'<span class="bk-val">-{_format_amount(payment.coupon_discount, currency)}</span>'
            f'</div>'
        )

    points_row = ""
    if payment.points_used and payment.points_used > 0:
        points_row = (
            f'<div class="bk-row bk-discount">'
            f'<span class="bk-label">Points Used</span>'
            f'<span class="bk-val">-{payment.points_used}</span>'
            f'</div>'
        )

    task_title = "—"
    task_source = "normal"
    if task:
        task_title = task.title or f"Task #{task.id}"
        task_source = getattr(task, "task_source", "normal") or "normal"

    html = _RECEIPT_HTML.format(
        status_color=_status_color(payment.status),
        status_label=_status_label(payment.status),
        date=_format_date(payment.created_at),
        symbol=symbol,
        amount_display=f"{payment.final_amount / 100:.2f}" if payment.final_amount else "0.00",
        order_no=payment.order_no or "—",
        payment_method=_method_label(payment.payment_method),
        task_title=task_title,
        task_type=_task_type_label(task_source),
        counterpart_row=counterpart_row,
        total_amount=_format_amount(payment.total_amount, currency),
        coupon_row=coupon_row,
        points_row=points_row,
        final_amount=_format_amount(payment.final_amount, currency),
    )

    buffer = io.BytesIO()
    pisa_status = pisa.CreatePDF(html, dest=buffer)
    if pisa_status.err:
        logger.error("PDF generation failed: %s errors", pisa_status.err)
        raise RuntimeError("Failed to generate receipt PDF")
    return buffer.getvalue()
