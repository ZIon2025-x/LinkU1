const express = require("express");
const app = express();
// This is your test secret API key.
// ⚠️ 请使用环境变量，不要硬编码密钥
// 设置方式：export STRIPE_SECRET_KEY=sk_test_...
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY || 'sk_test_YOUR_SECRET_KEY_HERE');

app.use(express.static("public"));
app.use(express.json());

const calculateOrderAmount = (items) => {
  // Calculate the order total on the server to prevent
  // people from directly manipulating the amount on the client
  let total = 0;
  items.forEach((item) => {
    total += item.amount;
  });
  return total;
};

app.post("/create-payment-intent", async (req, res) => {
  const { items } = req.body;

  // Create a PaymentIntent with the order amount and currency
  const paymentIntent = await stripe.paymentIntents.create({
    amount: calculateOrderAmount(items),
    currency: "gbp",
    // In the latest version of the API, specifying the `automatic_payment_methods` parameter is optional because Stripe enables its functionality by default.
    automatic_payment_methods: {
      enabled: true,
    },
  });

  res.send({
    clientSecret: paymentIntent.client_secret,
  });
});



app.listen(4242, () => console.log("Node server listening on port 4242!"));