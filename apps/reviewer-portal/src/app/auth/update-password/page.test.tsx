// @vitest-environment jsdom
import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ getUser: vi.fn(), updateUser: vi.fn() }));
vi.mock("@/lib/supabase/browser", () => ({ createBrowserSupabase: () => ({ auth: mocks }) }));
vi.mock("@/components/auth-shell", () => ({ AuthShell: ({ children }: { children: React.ReactNode }) => <div>{children}</div> }));
import UpdatePassword from "./page";

describe("Set a New Password", () => {
  beforeEach(() => { mocks.getUser.mockReset(); mocks.updateUser.mockReset(); history.replaceState({}, "", "/auth/update-password"); });
  afterEach(cleanup);
  it("shows the expired-link state without a session", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null } });
    render(<UpdatePassword />);
    expect(await screen.findByText(/invalid or has expired/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Request New Link" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Update Password" })).not.toBeInTheDocument();
  });
  it("blocks mismatched passwords and updates only after a fresh session check", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: "reviewer" } } });
    mocks.updateUser.mockResolvedValue({ error: null });
    render(<UpdatePassword />);
    await screen.findByRole("button", { name: "Update Password" });
    fireEvent.change(screen.getByLabelText("New password"), { target: { value: "long-password-one" } });
    fireEvent.change(screen.getByLabelText("Confirm new password"), { target: { value: "long-password-two" } });
    fireEvent.click(screen.getByRole("button", { name: "Update Password" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("The passwords do not match.");
    expect(mocks.updateUser).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText("Confirm new password"), { target: { value: "long-password-one" } });
    fireEvent.click(screen.getByRole("button", { name: "Update Password" }));
    await waitFor(() => expect(mocks.updateUser).toHaveBeenCalledWith({ password: "long-password-one" }));
    expect(await screen.findByText("Your password has been updated successfully.")).toBeInTheDocument();
  });
  it("does not update if the session expires before submit", async () => {
    mocks.getUser.mockResolvedValueOnce({ data: { user: { id: "reviewer" } } }).mockResolvedValueOnce({ data: { user: null } });
    render(<UpdatePassword />);
    await screen.findByRole("button", { name: "Update Password" });
    fireEvent.change(screen.getByLabelText("New password"), { target: { value: "long-password-one" } });
    fireEvent.change(screen.getByLabelText("Confirm new password"), { target: { value: "long-password-one" } });
    fireEvent.click(screen.getByRole("button", { name: "Update Password" }));
    expect(await screen.findByText(/invalid or has expired/)).toBeInTheDocument();
    expect(mocks.updateUser).not.toHaveBeenCalled();
  });
});
