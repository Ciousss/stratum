import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const contract = "stratum";
const accounts = simnet.getAccounts();
const creator = accounts.get("wallet_2")!;
const buyer = accounts.get("wallet_3")!;
const rater = accounts.get("wallet_4")!;

const makeKeyHash = () => Cl.buffer(new Uint8Array(32).fill(1));

const makeContentArgs = (price = 1000) => [
  Cl.stringAscii("cid-1"),
  makeKeyHash(),
  Cl.uint(price),
  Cl.stringAscii("art"),
  Cl.stringAscii("Genesis"),
  Cl.stringAscii("First release"),
  Cl.list([Cl.stringAscii("stacks"), Cl.stringAscii("design")]),
  Cl.stringAscii("document"),
];

const unwrapOk = (result: any) => {
  expect(result).toBeOk(expect.anything());
  return result.value;
};

const getContractOwner = () => {
  const ownerResult = simnet.callReadOnlyFn(contract, "get-contract-owner", [], creator);
  const ownerCv = unwrapOk(ownerResult.result);
  return ownerCv.value as string;
};

const registerContent = (sender = creator, price = 1000) => {
  const { result } = simnet.callPublicFn(contract, "register-content", makeContentArgs(price), sender);
  return unwrapOk(result);
};

describe("stratum core flows", () => {
  it("registers content and initializes analytics and ratings", () => {
    const contentId = registerContent();

    const count = simnet.callReadOnlyFn(contract, "get-content-count", [], creator);
    expect(count.result).toBeOk(contentId);

    const analytics = simnet.callReadOnlyFn(contract, "get-content-analytics", [contentId], creator);
    expect(analytics.result).toBeOk(
      Cl.tuple({
        "view-count": Cl.uint(0),
        "purchase-count": Cl.uint(0),
        "revenue-generated": Cl.uint(0),
      }),
    );

    const rating = simnet.callReadOnlyFn(contract, "get-content-rating", [contentId], creator);
    expect(rating.result).toBeOk(
      Cl.tuple({
        "total-rating": Cl.uint(0),
        "rating-count": Cl.uint(0),
        "average-rating": Cl.uint(0),
      }),
    );
  });

  it("buys access and updates analytics", () => {
    const price = 1000;
    const contentId = registerContent(creator, price);

    const purchase = simnet.callPublicFn(contract, "buy-access", [contentId], buyer);
    expect(purchase.result).toBeOk(Cl.bool(true));

    const access = simnet.callReadOnlyFn(
      contract,
      "has-access",
      [contentId, Cl.principal(buyer)],
      buyer,
    );
    expect(access.result).toBeOk(Cl.bool(true));

    const analytics = simnet.callReadOnlyFn(contract, "get-content-analytics", [contentId], buyer);
    expect(analytics.result).toBeOk(
      Cl.tuple({
        "view-count": Cl.uint(0),
        "purchase-count": Cl.uint(1),
        "revenue-generated": Cl.uint(price),
      }),
    );
  });

  it("rejects duplicate access purchases", () => {
    const contentId = registerContent();

    const purchase = simnet.callPublicFn(contract, "buy-access", [contentId], buyer);
    expect(purchase.result).toBeOk(Cl.bool(true));

    const duplicate = simnet.callPublicFn(contract, "buy-access", [contentId], buyer);
    expect(duplicate.result).toBeErr(Cl.uint(102));
  });

  it("grants access through subscriptions", () => {
    const contentId = registerContent();

    const subscription = simnet.callPublicFn(
      contract,
      "create-subscription",
      [
        contentId,
        Cl.stringAscii("gold"),
        Cl.uint(100),
        Cl.uint(500),
        Cl.uint(5),
        Cl.list([Cl.stringAscii("full-access")]),
      ],
      creator,
    );
    const subscriptionId = unwrapOk(subscription.result);

    const purchase = simnet.callPublicFn(contract, "buy-subscription", [subscriptionId], buyer);
    expect(purchase.result).toBeOk(Cl.bool(true));

    const access = simnet.callReadOnlyFn(
      contract,
      "has-access-enhanced",
      [contentId, Cl.principal(buyer)],
      buyer,
    );
    expect(access.result).toBeOk(Cl.bool(true));
  });

  it("enforces rating access and updates aggregates", () => {
    const contentId = registerContent();

    const denied = simnet.callPublicFn(
      contract,
      "rate-content",
      [contentId, Cl.uint(5), Cl.stringAscii("great")],
      rater,
    );
    expect(denied.result).toBeErr(Cl.uint(100));

    const purchase = simnet.callPublicFn(contract, "buy-access", [contentId], rater);
    expect(purchase.result).toBeOk(Cl.bool(true));

    const rate = simnet.callPublicFn(
      contract,
      "rate-content",
      [contentId, Cl.uint(5), Cl.stringAscii("great")],
      rater,
    );
    expect(rate.result).toBeOk(Cl.bool(true));

    const rating = simnet.callReadOnlyFn(contract, "get-content-rating", [contentId], rater);
    expect(rating.result).toBeOk(
      Cl.tuple({
        "total-rating": Cl.uint(5),
        "rating-count": Cl.uint(1),
        "average-rating": Cl.uint(5),
      }),
    );

    const duplicate = simnet.callPublicFn(
      contract,
      "rate-content",
      [contentId, Cl.uint(4), Cl.stringAscii("second")],
      rater,
    );
    expect(duplicate.result).toBeErr(Cl.uint(113));
  });

  it("blocks writes while paused", () => {
    const contractOwner = getContractOwner();
    const pause = simnet.callPublicFn(contract, "pause-contract", [], contractOwner);
    expect(pause.result).toBeOk(Cl.bool(true));

    const attempt = simnet.callPublicFn(contract, "register-content", makeContentArgs(), creator);
    expect(attempt.result).toBeErr(Cl.uint(107));

    const paused = simnet.callReadOnlyFn(contract, "is-contract-paused", [], contractOwner);
    expect(paused.result).toBeOk(Cl.bool(true));
  });
});
