const APPROVAL_PATTERNS = [
  /\b(approve|approval|permission|allow|authorize)\b/i,
  /\b(do you want|would you like)\b.*\b(proceed|continue|run|edit|apply)\b/i,
  /\b(y\/n|yes\/no)\b/i
];

export function looksLikeApprovalRequest(text: string): boolean {
  return APPROVAL_PATTERNS.some((pattern) => pattern.test(text));
}
