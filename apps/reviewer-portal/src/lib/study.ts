export const HE001_STUDY_KEY = process.env.TAFSIRI_STUDY_KEY ?? "HUMAN_EVALUATION_001_LUWANGA";
export const HE001_PARTICIPATION_VERSION = "HE001-PARTICIPATION-V1";
export const LUWANGA_DIALECT_NAME = "Luwanga";
export const EXPERTISE_LEVELS = ["native", "fluent", "advanced", "familiar"] as const;
export type ExpertiseLevel = typeof EXPERTISE_LEVELS[number];
