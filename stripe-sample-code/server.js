const express = require("express");
const app = express();

const stripe = require("stripe")(
  // This is your test secret API key.
  // IMPORTANT: Use environment variable for production
  // Set STRIPE_SECRET_KEY environment variable
  process.env.STRIPE_SECRET_KEY || 'sk_test_YOUR_KEY_HERE'
);

app.use(express.static("dist"));
app.use(express.json());

app.post("/account_session", async (req, res) => {
  try {
    const { account } = req.body;

    const accountSession = await stripe.accountSessions.create({
      account: account,
      components: {
        account_onboarding: { enabled: true },
      },
    });

    res.json({
      client_secret: accountSession.client_secret,
    });
  } catch (error) {
    console.error(
      "An error occurred when calling the Stripe API to create an account session",
      error
    );
    res.status(500);
    res.send({ error: error.message });
  }
});

app.post("/account", async (req, res) => {
  try {
    const account = await stripe.v2.core.accounts.create({
      dashboard: 'express',
      contact_email: 'person@example.com',
      defaults: {
        responsibilities: {
          fees_collector: 'application',
          losses_collector: 'application',
        },
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
      identity: {
        country: 'GB',
      },
      include: [
        'configuration.merchant',
        'configuration.recipient',
        'identity',
        'defaults',
      ],
    });

    res.json({
      account: account.id,
    });
  } catch (error) {
    console.error(
      "An error occurred when calling the Stripe API to create an account",
      error
    );
    res.status(500);
    res.send({ error: error.message });
  }
});

app.get("/*", (_req, res) => {
  res.sendFile(__dirname + "/dist/index.html");
});

app.listen(4242, () => console.log("Node server listening on port 4242! Visit http://localhost:4242 in your browser."));