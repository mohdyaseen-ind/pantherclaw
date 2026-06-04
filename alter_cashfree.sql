-- Rename Razorpay columns to Cashfree

ALTER TABLE public.users
RENAME COLUMN razorpay_customer_id TO cashfree_customer_id;

ALTER TABLE public.orders
RENAME COLUMN razorpay_order_id TO cashfree_order_id;

ALTER TABLE public.payments
RENAME COLUMN razorpay_payment_id TO cashfree_payment_id;

ALTER TABLE public.payments
RENAME COLUMN razorpay_signature TO cashfree_signature;

ALTER TABLE public.payments
RENAME COLUMN razorpay_refund_id TO cashfree_refund_id;
