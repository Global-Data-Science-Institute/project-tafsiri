// @vitest-environment jsdom
import "@testing-library/jest-dom/vitest";
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
const mocks=vi.hoisted(()=>({submitStageA:vi.fn()}));
vi.mock("../actions",()=>({submitStageA:mocks.submitStageA}));
vi.mock("next/navigation",()=>({useRouter:()=>({refresh:vi.fn()})}));
import StageAForm from "./stage-a-form";
const initial={decision:"",label:"",definition:"",notes:""};
const response=()=>new Response(JSON.stringify({savedAt:"2026-08-13T12:00:00Z"}),{status:200,headers:{"content-type":"application/json"}});
describe("Stage A autosave",()=>{
 beforeEach(()=>{vi.useFakeTimers();mocks.submitStageA.mockReset();global.fetch=vi.fn(async()=>response())});
 afterEach(()=>{cleanup();vi.useRealTimers()});
 it("debounces rapid edits and reports only confirmed saving",async()=>{
  render(<StageAForm assignmentId="a" initial={initial}/>);fireEvent.click(screen.getByLabelText(/One clear meaning/));fireEvent.change(screen.getByLabelText(/Suggested concept label/),{target:{value:"first"}});fireEvent.change(screen.getByLabelText(/Suggested concept label/),{target:{value:"latest"}});
  expect(screen.getByRole("status")).toHaveTextContent("Saving");expect(fetch).not.toHaveBeenCalled();await act(async()=>vi.advanceTimersByTimeAsync(800));expect(fetch).toHaveBeenCalledTimes(1);expect(String((fetch as ReturnType<typeof vi.fn>).mock.calls[0][1]?.body)).toContain("latest");expect(screen.getByRole("status")).toHaveTextContent("Saved at");
 });
 it("flushes the latest draft before Stage A submission",async()=>{
  let release!:()=>void,calls=0;global.fetch=vi.fn(()=>++calls===1?new Promise<Response>(resolve=>{release=()=>resolve(response())}):Promise.resolve(response()));render(<StageAForm assignmentId="a" initial={initial}/>);fireEvent.click(screen.getByLabelText(/One clear meaning/));await act(async()=>vi.advanceTimersByTimeAsync(800));fireEvent.click(screen.getByRole("button",{name:"Submit Linguistic Judgment"}));expect(mocks.submitStageA).not.toHaveBeenCalled();await act(async()=>release());expect(mocks.submitStageA).toHaveBeenCalledTimes(1);const submitted=mocks.submitStageA.mock.calls[0][0] as FormData;expect(submitted.get("decision")).toBe("ACCEPT_SIMPLE");
 });
 it("keeps editing available after a transient failure",async()=>{
  global.fetch=vi.fn(async()=>new Response(JSON.stringify({message:"no"}),{status:500,headers:{"content-type":"application/json"}}));render(<StageAForm assignmentId="a" initial={initial}/>);fireEvent.click(screen.getByLabelText(/One clear meaning/));await act(async()=>vi.advanceTimersByTimeAsync(800));expect(screen.getByRole("status")).toHaveTextContent("Unable to save");expect(screen.getByLabelText(/Suggested concept label/)).toBeEnabled();
 });
});
