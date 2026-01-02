require("dotenv").config();
const { Stripe } = require("stripe");
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

const express = require("express");
const app = express();
const router = express.Router();
app.use(express.static("public"));

// // Thin webhook must see the raw body before any JSON/urlencoded parsers run
app.post(
  "/api/thin-webhook",
  express.raw({ type: "application/json" }),
  async (request, response) => {
    // Replace this endpoint secret with your endpoint's unique secret
    // If you are testing with the CLI, find the secret by running 'stripe listen'
    // If you are using an endpoint defined with the API or dashboard, look in your webhook settings
    // at https://dashboard.stripe.com/webhooks
    const thinEndpointSecret = "";
    const signature = request.headers["stripe-signature"];
    let eventNotif;
    try {
      eventNotif = stripe.parseEventNotification(
        request.body,
        signature,
        thinEndpointSecret
      );
    } catch (err) {
      console.log(`⚠️  Webhook signature verification failed.`, err.message);
      return response.sendStatus(400);
    }

    if (eventNotif.type === "v2.account.created") {
      await eventNotif.fetchRelatedObject();
      await eventNotif.fetchEvent();
    } else {
      console.log(`Unhandled event type ${eventNotif.type}.`);
    }

    response.send();
  }
);

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// Create a sample product and return a price for it
router.post("/create-product", async (req, res) => {
  const productName = req.body.productName;
  const productDescription = req.body.productDescription;
  const productPrice = req.body.productPrice;
  const accountId = req.body.accountId; // Get the connected account ID

  try {
    // Create the product on the platform
    const product = await stripe.products.create(
      {
        name: productName,
        description: productDescription,
        metadata: { stripeAccount: accountId }
      }
    );

    // Create a price for the product on the platform
    const price = await stripe.prices.create(
      {
        product: product.id,
        unit_amount: productPrice,
        currency: "gbp",
        metadata: { stripeAccount: accountId }
      },
    );

    res.json({
      productName: productName,
      productDescription: productDescription,
      productPrice: productPrice,
      priceId: price.id,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create a Connected Account
router.post("/create-connect-account", async (req, res) => {
  try {
    // Create a Connect account with the specified controller properties
    const account = await stripe.v2.core.accounts.create({
      display_name: req.body.email,
      contact_email: req.body.email,
      dashboard: "express",
      defaults: {
        responsibilities: {
          fees_collector: "application",
          losses_collector: "application",
        },
      },
      identity: {
        country: "GB",
        entity_type: "company",
      },
      configuration: {
        recipient: {
          capabilities: {
            stripe_balance: {
              stripe_transfers: {
                requested: true,
              },
            },
          },
        },
      },
    });

    res.json({ accountId: account.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create Account Link for onboarding
router.post("/create-account-link", async (req, res) => {
  const accountId = req.body.accountId;
  try {
    const accountLink = await stripe.v2.core.accountLinks.create({
      account: accountId,
      use_case: {
        type: 'account_onboarding',
        account_onboarding: {
          configurations: ['recipient'],
          refresh_url: 'https://example.com',
          return_url: `https://example.com?accountId=${accountId}`,
        },
      },
    });
    res.json({ url: accountLink.url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get Connected Account Status
router.get("/account-status/:accountId", async (req, res) => {
  try {
    const account = await stripe.v2.core.accounts.retrieve(
      req.params.accountId,
      {
        include: ['requirements', 'configuration.recipient'],
      }
    );
    const payoutsEnabled = account.configuration?.recipient?.capabilities?.stripe_balance?.payouts?.status === 'active'
    const chargesEnabled = account.configuration?.recipient?.capabilities?.stripe_balance?.stripe_transfers?.status === 'active'

    // No pending requirments
    const summaryStatus = account.requirements?.summary?.minimum_deadline?.status
    const detailsSubmitted = !summaryStatus || summaryStatus === 'eventually_due'

    res.json({
      id: account.id,
      payoutsEnabled,
      chargesEnabled,
      detailsSubmitted,
      requirements: account.requirements?.entries,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Fetch products for a specific account
router.get("/products/:accountId", async (req, res) => {
  const { accountId } = req.params;

  try {
    const prices = await stripe.prices.search({
      query: `metadata['stripeAccount']:'${accountId}' AND active:'true'`,
      expand: ["data.product"],
      limit: 100,
    });

    res.json(
      prices.data.map((price) => ({
        id: price.product.id,
        name: price.product.name,
        description: price.product.description,
        price: price.unit_amount,
        priceId: price.id,
        period: price.recurring ? price.recurring.interval : null,
        image: "https://i.imgur.com/6Mvijcm.png",
      }))
    );
  } catch (err) {
    console.error("Error fetching prices:", err);
    res.status(500).json({ error: err.message });
  }
});

// Create checkout session
router.post("/create-checkout-session", async (req, res) => {
  const { priceId, accountId } = req.body;

  // Get the price's type from Stripe
  const price = await stripe.prices.retrieve(priceId);
  const priceType = price.type;
  const mode = priceType === 'recurring' ? 'subscription' : 'payment';

  const session = await stripe.checkout.sessions.create({
    line_items: [
      {
        price: priceId,
        quantity: 1,
      },
    ],
    mode: mode,
    // Defines where Stripe will redirect a customer after successful payment
    success_url: `${process.env.DOMAIN}/done?session_id={CHECKOUT_SESSION_ID}`,
    // Defines where Stripe will redirect if a customer cancels payment
    cancel_url: `${process.env.DOMAIN}`,
    ...(mode === 'subscription' ? {
      subscription_data: {
        application_fee_amount: 123,
        transfer_data: {
          destination: accountId,
        },
      },
    } : {
      payment_intent_data: {
        application_fee_amount: 123,
        transfer_data: {
          destination: accountId,
        },
      },
    }),
  });

  // Redirect to the Stripe hosted checkout URL
  res.redirect(303, session.url);
});



router.post(
  "/webhook",
  express.raw({ type: "application/json" }),
  (request, response) => {
    let event = request.body;
    // Replace this endpoint secret with your endpoint's unique secret
    // If you are testing with the CLI, find the secret by running 'stripe listen'
    // If you are using an endpoint defined with the API or dashboard, look in your webhook settings
    // at https://dashboard.stripe.com/webhooks
    const endpointSecret = "";

    // Only verify the event if you have an endpoint secret defined.
    // Otherwise use the basic event deserialized with JSON.parse
    if (endpointSecret) {
      const signature = request.headers["stripe-signature"];
      try {
        event = stripe.webhooks.constructEvent(
          request.body,
          signature,
          endpointSecret
        );
      } catch (err) {
        console.log(`⚠️  Webhook signature verification failed.`, err.message);
        return response.sendStatus(400);
      }
    }

    let stripeObject;
    let status;
    // Handle the event
    switch (event.type) {
      case "checkout.session.completed":
        stripeObject = event.data.object;
        status = stripeObject.status;
        console.log(`Checkout Session status is ${status}.`);
        // Then define and call a method to handle the subscription deleted.
        // handleCheckoutSessionCompleted(stripeObject);
        break;
      case "checkout.session.async_payment_failed":
        stripeObject = event.data.object;
        status = stripeObject.status;
        console.log(`Checkout Session status is ${status}.`);
        // Then define and call a method to handle the subscription deleted.
        // handleCheckoutSessionFailed(stripeObject);
        break;

      default:
        // Unexpected event type
        console.log(`Unhandled event type ${event.type}.`);
    }
    // Return a 200 response to acknowledge receipt of the event
    response.send();
  }
);

app.use("/api", router);

app.listen(4242, () => console.log("Server running on port 4242"));

