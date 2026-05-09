


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "mvp";


ALTER SCHEMA "mvp" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "prism_audit";


ALTER SCHEMA "prism_audit" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "prism_core";


ALTER SCHEMA "prism_core" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "prism_editor";


ALTER SCHEMA "prism_editor" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "prism_guard";


ALTER SCHEMA "prism_guard" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "prism_core"."has_blocked_clinical_language"("input_text" "text") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $_$
  select coalesce(input_text, '') ~* $rx$(patient should|clinician should|treat with|progress when|prescribe|return at|clear for sport|recommended care|use this intervention|clinical protocol|best treatment|correct plan|diagnosis|dosage|protocol|what to do with|clearance)$rx$;
$_$;


ALTER FUNCTION "prism_core"."has_blocked_clinical_language"("input_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "prism_core"."has_replacement_risk"("input_text" "text") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $_$
  select coalesce(input_text, '') ~* $rx$(full summary|complete summary|article summary|abstract|table [0-9]|figure [0-9]|skip the paper|replaces the article|all you need)$rx$;
$_$;


ALTER FUNCTION "prism_core"."has_replacement_risk"("input_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "prism_guard"."block_api_table_direct_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  raise exception 'Direct changes to Prism API tables are blocked. Rebuild through a release task instead.';
end;
$$;


ALTER FUNCTION "prism_guard"."block_api_table_direct_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "prism_guard"."block_app_payload_direct_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  raise exception 'Direct changes to app_acl_rts_student_payload_v01 are blocked. Create a new release table or use an editor workflow instead.';
end;
$$;


ALTER FUNCTION "prism_guard"."block_app_payload_direct_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_evidence"("search_text" "text") RETURNS TABLE("evidence_id" "text", "source_title" "text", "concept_zone" "text", "source_linked_finding" "text", "numeric_result" "text", "evidence_boundary" "text", "do_not_use_as" "text")
    LANGUAGE "sql" STABLE
    AS $$
  select
    eo.evidence_id,
    s.title as source_title,
    eo.concept_zone,
    eo.source_linked_finding,
    eo.numeric_result,
    eo.evidence_boundary,
    eo.do_not_use_as
  from evidence_objects eo
  left join sources s
    on eo.source_id = s.source_id
  where
    eo.source_linked_finding ilike '%' || search_text || '%'
    or eo.concept_zone ilike '%' || search_text || '%'
    or eo.numeric_result ilike '%' || search_text || '%'
    or eo.evidence_boundary ilike '%' || search_text || '%'
    or eo.prism_use ilike '%' || search_text || '%';
$$;


ALTER FUNCTION "public"."search_evidence"("search_text" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."evidence_objects" (
    "evidence_id" "text" NOT NULL,
    "source_id" "text",
    "evidence_number" "text",
    "construct_ids" "text",
    "concept_zone" "text",
    "source_anchor" "text",
    "source_linked_finding" "text",
    "numeric_result" "text",
    "author_interpretation" "text",
    "evidence_boundary" "text",
    "prism_use" "text",
    "do_not_use_as" "text",
    "curiosity_question" "text",
    "certainty_flag" "text",
    "extraction_review_status" "text" DEFAULT 'needs_review'::"text",
    "extraction_reviewer_note" "text",
    "source_traceability_status" "text" DEFAULT 'needs_review'::"text",
    "close_paraphrase_risk" "text" DEFAULT 'needs_scan'::"text",
    "clinical_language_status" "text" DEFAULT 'needs_scan'::"text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "public_readiness_status" "text" DEFAULT 'not_public_ready'::"text",
    "evidence_role_review_status" "text" DEFAULT 'needs_review'::"text",
    "concept_zone_review_status" "text" DEFAULT 'needs_review'::"text"
);


ALTER TABLE "public"."evidence_objects" OWNER TO "postgres";


COMMENT ON TABLE "public"."evidence_objects" IS 'Core evidence object spine. Stores source-linked findings and raw framework fields. Public wording belongs in prism_evidence_curation.';



COMMENT ON COLUMN "public"."evidence_objects"."certainty_flag" IS 'DEPRECATED. Do not use in public UI. Replaced by confidence_level, uncertainty_flag, and risk_category in prism_evidence_curation.';



CREATE TABLE IF NOT EXISTS "public"."prism_evidence_curation" (
    "evidence_id" "text" NOT NULL,
    "public_title" "text",
    "public_finding" "text",
    "public_boundary" "text",
    "public_framework_application" "text",
    "public_open_question" "text",
    "source_supports" "text",
    "source_does_not_establish" "text",
    "evidence_role" "text",
    "confidence_level" "text",
    "uncertainty_flag" "text",
    "risk_category" "text",
    "source_role" "text",
    "concept_zone_override" "text",
    "human_review_status" "text" DEFAULT 'needs_review'::"text" NOT NULL,
    "curation_status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "approved_for_public" boolean DEFAULT false NOT NULL,
    "reviewer_note" "text",
    "blocked_language_flag" boolean DEFAULT false NOT NULL,
    "replacement_risk_status" "text" DEFAULT 'needs_scan'::"text",
    "source_traceability_status" "text" DEFAULT 'needs_review'::"text",
    "boundary_review_status" "text" DEFAULT 'needs_review'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."prism_evidence_curation" OWNER TO "postgres";


COMMENT ON TABLE "public"."prism_evidence_curation" IS 'Human curation table. Stores public-facing wording, review status, safety flags, and approval fields.';



CREATE TABLE IF NOT EXISTS "public"."sources" (
    "source_id" "text" NOT NULL,
    "title" "text",
    "citation" "text",
    "doi" "text",
    "journal" "text",
    "year" "text",
    "source_type" "text",
    "design_label" "text",
    "population_scope" "text",
    "article_type_label" "text",
    "pages" "text",
    "source_file" "text",
    "source_review_status" "text" DEFAULT 'needs_review'::"text",
    "provenance_status" "text" DEFAULT 'needs_review'::"text",
    "access_rights_status" "text" DEFAULT 'needs_review'::"text",
    "source_role" "text",
    "source_role_rationale" "text",
    "curation_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "source_quality_note" "text"
);


ALTER TABLE "public"."sources" OWNER TO "postgres";


CREATE OR REPLACE VIEW "mvp"."evidence_cards_preview" AS
 SELECT "pec"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    "s"."journal",
    "s"."year",
    "s"."source_type",
    "s"."design_label",
    "s"."population_scope",
    COALESCE("pec"."concept_zone_override", "eo"."concept_zone") AS "concept_zone",
    "pec"."public_title" AS "title",
    "pec"."public_finding" AS "finding",
    "pec"."public_boundary" AS "evidence_boundary",
    "pec"."public_framework_application" AS "framework_application",
    "pec"."public_open_question" AS "curiosity_question",
    "pec"."source_supports",
    "pec"."source_does_not_establish",
    "pec"."evidence_role",
    "pec"."source_role",
    "pec"."confidence_level",
    "pec"."uncertainty_flag",
    "pec"."risk_category",
    "pec"."curation_status",
    "pec"."human_review_status",
    "pec"."approved_for_public",
    "pec"."blocked_language_flag",
    "pec"."replacement_risk_status",
    "pec"."source_traceability_status",
    "pec"."boundary_review_status",
    "eo"."certainty_flag",
    "eo"."close_paraphrase_risk",
    "eo"."clinical_language_status",
    "eo"."public_readiness_status",
    "pec"."updated_at"
   FROM (("public"."prism_evidence_curation" "pec"
     JOIN "public"."evidence_objects" "eo" ON (("eo"."evidence_id" = "pec"."evidence_id")))
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "eo"."source_id")));


ALTER VIEW "mvp"."evidence_cards_preview" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_audit"."card_refinement_workspace" (
    "evidence_id" "text" NOT NULL,
    "source_id" "text",
    "source_title" "text",
    "concept_zone" "text",
    "original_public_title" "text",
    "original_public_finding" "text",
    "original_public_boundary" "text",
    "original_public_framework_application" "text",
    "original_public_open_question" "text",
    "revised_title" "text",
    "revised_finding" "text",
    "revised_boundary" "text",
    "revised_framework_application" "text",
    "revised_curiosity_question" "text",
    "reviewer_note" "text",
    "ready_for_public" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_audit"."card_refinement_workspace" OWNER TO "postgres";


CREATE OR REPLACE VIEW "mvp"."evidence_cards_public" AS
 SELECT "crw"."evidence_id",
    "crw"."source_id",
    "crw"."source_title",
    "s"."citation",
    "s"."doi",
    "s"."journal",
    "s"."year",
    "s"."source_type",
    "crw"."concept_zone",
    "crw"."revised_title" AS "title",
    "crw"."revised_finding" AS "finding",
    "crw"."revised_boundary" AS "evidence_boundary",
    "crw"."revised_framework_application" AS "framework_application",
    "crw"."revised_curiosity_question" AS "curiosity_question",
    'Source-linked educational framework. Not a replacement for the original article.'::"text" AS "source_safety_note",
    'Read the original source for full methods, results, and author interpretation.'::"text" AS "read_original_source_prompt"
   FROM ("prism_audit"."card_refinement_workspace" "crw"
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "crw"."source_id")))
  WHERE ("crw"."ready_for_public" = true);


ALTER VIEW "mvp"."evidence_cards_public" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_audit"."public_card_language_audit" AS
 SELECT "pec"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    COALESCE("pec"."concept_zone_override", "eo"."concept_zone") AS "concept_zone",
    "pec"."public_title",
    "pec"."public_finding",
    "pec"."public_boundary",
    "pec"."public_framework_application",
    "pec"."public_open_question",
    "pec"."source_supports",
    "pec"."source_does_not_establish",
    "pec"."evidence_role",
    "pec"."source_role",
    "pec"."confidence_level",
    "pec"."uncertainty_flag",
    "pec"."risk_category",
    "pec"."approved_for_public",
    "pec"."blocked_language_flag",
    "pec"."replacement_risk_status",
    "pec"."source_traceability_status",
    "pec"."boundary_review_status",
    "pec"."human_review_status",
    "array_remove"(ARRAY[
        CASE
            WHEN (("pec"."public_title" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_title")) < 8)) THEN 'missing_or_weak_title'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("length"(COALESCE("pec"."public_title", ''::"text")) > 90) THEN 'title_too_long'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("pec"."public_finding" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_finding")) < 40)) THEN 'missing_or_weak_finding'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("length"(COALESCE("pec"."public_finding", ''::"text")) > 420) THEN 'finding_too_long_for_card'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("pec"."public_boundary" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_boundary")) < 45)) THEN 'missing_or_weak_boundary'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("pec"."public_boundary" !~* '(does not establish|does not show|does not prove|cannot|doesn''t establish|not a|limited by|should not be used)'::"text") THEN 'boundary_may_not_explicitly_limit_overclaiming'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("pec"."public_framework_application" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_framework_application")) < 45)) THEN 'missing_or_weak_framework_application'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("pec"."public_framework_application" !~* '(helps organize|helps students|helps a student|frames|places|connects|mental model|understand|map|clarify)'::"text") THEN 'framework_application_may_not_sound_prism_native'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("pec"."public_open_question" IS NULL) OR ("right"(TRIM(BOTH FROM "pec"."public_open_question"), 1) <> '?'::"text")) THEN 'open_question_missing_or_not_question'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("pec"."source_supports" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."source_supports")) < 20)) THEN 'missing_source_supports'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("pec"."source_does_not_establish" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."source_does_not_establish")) < 20)) THEN 'missing_source_does_not_establish'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_title", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application", "pec"."public_open_question") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 'blocked_clinical_language_scan_required'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application") ~* '(this study proves|evidence proves|guarantees|definitive|always|never)'::"text") THEN 'fake_certainty_scan_required'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("pec"."replacement_risk_status" IS DISTINCT FROM 'cleared'::"text") THEN 'replacement_risk_not_final_cleared'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("pec"."source_traceability_status" IS DISTINCT FROM 'cleared'::"text") THEN 'source_traceability_not_final_cleared'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("pec"."boundary_review_status" IS DISTINCT FROM 'cleared'::"text") THEN 'boundary_not_final_cleared'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("pec"."human_review_status" IS DISTINCT FROM 'approved'::"text") THEN 'human_review_not_final_approved'::"text"
            ELSE NULL::"text"
        END], NULL::"text") AS "audit_flags",
    ((((((((((((((((
        CASE
            WHEN (("pec"."public_title" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_title")) < 8)) THEN 2
            ELSE 0
        END +
        CASE
            WHEN ("length"(COALESCE("pec"."public_title", ''::"text")) > 90) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_finding" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_finding")) < 40)) THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("length"(COALESCE("pec"."public_finding", ''::"text")) > 420) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_boundary" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_boundary")) < 45)) THEN 4
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."public_boundary" !~* '(does not establish|does not show|does not prove|cannot|doesn''t establish|not a|limited by|should not be used)'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_framework_application" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_framework_application")) < 45)) THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."public_framework_application" !~* '(helps organize|helps students|helps a student|frames|places|connects|mental model|understand|map|clarify)'::"text") THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_open_question" IS NULL) OR ("right"(TRIM(BOTH FROM "pec"."public_open_question"), 1) <> '?'::"text")) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."source_supports" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."source_supports")) < 20)) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."source_does_not_establish" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."source_does_not_establish")) < 20)) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_title", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application", "pec"."public_open_question") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 5
            ELSE 0
        END) +
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application") ~* '(this study proves|evidence proves|guarantees|definitive|always|never)'::"text") THEN 4
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."replacement_risk_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."source_traceability_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."boundary_review_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."human_review_status" IS DISTINCT FROM 'approved'::"text") THEN 3
            ELSE 0
        END) AS "audit_score",
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_title", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application", "pec"."public_open_question") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 'repair_before_any_demo'::"text"
            WHEN ("pec"."risk_category" ~~* '%high%'::"text") THEN 'human_review_before_demo'::"text"
            WHEN ("pec"."public_boundary" !~* '(does not establish|does not show|does not prove|cannot|doesn''t establish|not a|limited by|should not be used)'::"text") THEN 'repair_boundary'::"text"
            WHEN ("length"(COALESCE("pec"."public_finding", ''::"text")) > 420) THEN 'compress_for_student_card'::"text"
            WHEN ("pec"."source_traceability_status" IS DISTINCT FROM 'cleared'::"text") THEN 'source_check_needed'::"text"
            ELSE 'candidate_for_founder_review'::"text"
        END AS "next_card_action"
   FROM (("public"."prism_evidence_curation" "pec"
     JOIN "public"."evidence_objects" "eo" ON (("eo"."evidence_id" = "pec"."evidence_id")))
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "eo"."source_id")))
  ORDER BY ((((((((((((((((
        CASE
            WHEN (("pec"."public_title" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_title")) < 8)) THEN 2
            ELSE 0
        END +
        CASE
            WHEN ("length"(COALESCE("pec"."public_title", ''::"text")) > 90) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_finding" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_finding")) < 40)) THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("length"(COALESCE("pec"."public_finding", ''::"text")) > 420) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_boundary" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_boundary")) < 45)) THEN 4
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."public_boundary" !~* '(does not establish|does not show|does not prove|cannot|doesn''t establish|not a|limited by|should not be used)'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_framework_application" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."public_framework_application")) < 45)) THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."public_framework_application" !~* '(helps organize|helps students|helps a student|frames|places|connects|mental model|understand|map|clarify)'::"text") THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_open_question" IS NULL) OR ("right"(TRIM(BOTH FROM "pec"."public_open_question"), 1) <> '?'::"text")) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."source_supports" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."source_supports")) < 20)) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."source_does_not_establish" IS NULL) OR ("length"(TRIM(BOTH FROM "pec"."source_does_not_establish")) < 20)) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_title", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application", "pec"."public_open_question") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 5
            ELSE 0
        END) +
        CASE
            WHEN ("concat_ws"(' '::"text", "pec"."public_finding", "pec"."public_boundary", "pec"."public_framework_application") ~* '(this study proves|evidence proves|guarantees|definitive|always|never)'::"text") THEN 4
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."replacement_risk_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."source_traceability_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."boundary_review_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."human_review_status" IS DISTINCT FROM 'approved'::"text") THEN 3
            ELSE 0
        END) DESC, "pec"."risk_category" DESC, "s"."title", "pec"."evidence_id";


ALTER VIEW "prism_audit"."public_card_language_audit" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_audit"."raw_extraction_audit" AS
 SELECT "eo"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "eo"."evidence_number",
    "eo"."concept_zone",
    "eo"."source_anchor",
    "eo"."source_linked_finding",
    "eo"."numeric_result",
    "eo"."author_interpretation",
    "eo"."evidence_boundary",
    "eo"."prism_use",
    "eo"."do_not_use_as",
    "eo"."curiosity_question",
    "eo"."certainty_flag",
    "eo"."extraction_review_status",
    "eo"."source_traceability_status",
    "eo"."close_paraphrase_risk",
    "eo"."clinical_language_status",
    "eo"."public_readiness_status",
    "array_remove"(ARRAY[
        CASE
            WHEN (("eo"."source_anchor" IS NULL) OR ("length"(TRIM(BOTH FROM COALESCE("eo"."source_anchor", ''::"text"))) = 0)) THEN 'missing_source_anchor'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("length"(COALESCE("eo"."source_linked_finding", ''::"text")) > 900) THEN 'raw_finding_too_long_for_public_use'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("eo"."source_linked_finding" ~* '(".*")'::"text") THEN 'contains_direct_quote_scan_required'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("concat_ws"(' '::"text", "eo"."source_linked_finding", "eo"."author_interpretation", "eo"."prism_use", "eo"."do_not_use_as") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 'clinical_drift_scan_required'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("eo"."evidence_boundary" IS NULL) OR ("length"(TRIM(BOTH FROM "eo"."evidence_boundary")) < 80)) THEN 'weak_or_missing_boundary'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("eo"."do_not_use_as" IS NULL) OR ("length"(TRIM(BOTH FROM "eo"."do_not_use_as")) < 40)) THEN 'missing_do_not_use_as'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN (("eo"."curiosity_question" IS NULL) OR ("right"(TRIM(BOTH FROM "eo"."curiosity_question"), 1) <> '?'::"text")) THEN 'curiosity_question_missing_or_not_question'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("eo"."source_traceability_status" IS DISTINCT FROM 'reviewed'::"text") THEN 'source_traceability_needs_review'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("eo"."close_paraphrase_risk" IS DISTINCT FROM 'cleared'::"text") THEN 'close_paraphrase_scan_needed'::"text"
            ELSE NULL::"text"
        END,
        CASE
            WHEN ("eo"."clinical_language_status" IS DISTINCT FROM 'cleared'::"text") THEN 'clinical_language_scan_needed'::"text"
            ELSE NULL::"text"
        END], NULL::"text") AS "audit_flags",
    (((((((((
        CASE
            WHEN (("eo"."source_anchor" IS NULL) OR ("length"(TRIM(BOTH FROM COALESCE("eo"."source_anchor", ''::"text"))) = 0)) THEN 2
            ELSE 0
        END +
        CASE
            WHEN ("length"(COALESCE("eo"."source_linked_finding", ''::"text")) > 900) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."source_linked_finding" ~* '(".*")'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("concat_ws"(' '::"text", "eo"."source_linked_finding", "eo"."author_interpretation", "eo"."prism_use", "eo"."do_not_use_as") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 4
            ELSE 0
        END) +
        CASE
            WHEN (("eo"."evidence_boundary" IS NULL) OR ("length"(TRIM(BOTH FROM "eo"."evidence_boundary")) < 80)) THEN 3
            ELSE 0
        END) +
        CASE
            WHEN (("eo"."do_not_use_as" IS NULL) OR ("length"(TRIM(BOTH FROM "eo"."do_not_use_as")) < 40)) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("eo"."curiosity_question" IS NULL) OR ("right"(TRIM(BOTH FROM "eo"."curiosity_question"), 1) <> '?'::"text")) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."source_traceability_status" IS DISTINCT FROM 'reviewed'::"text") THEN 2
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."close_paraphrase_risk" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."clinical_language_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) AS "audit_score"
   FROM ("public"."evidence_objects" "eo"
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "eo"."source_id")))
  ORDER BY (((((((((
        CASE
            WHEN (("eo"."source_anchor" IS NULL) OR ("length"(TRIM(BOTH FROM COALESCE("eo"."source_anchor", ''::"text"))) = 0)) THEN 2
            ELSE 0
        END +
        CASE
            WHEN ("length"(COALESCE("eo"."source_linked_finding", ''::"text")) > 900) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."source_linked_finding" ~* '(".*")'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("concat_ws"(' '::"text", "eo"."source_linked_finding", "eo"."author_interpretation", "eo"."prism_use", "eo"."do_not_use_as") ~* '(patient(s)? should|clinician(s)? should|progress when|treat with|prescribe|clear for|return at|use this intervention|recommended care|best treatment|correct plan|dosage|protocol instruction)'::"text") THEN 4
            ELSE 0
        END) +
        CASE
            WHEN (("eo"."evidence_boundary" IS NULL) OR ("length"(TRIM(BOTH FROM "eo"."evidence_boundary")) < 80)) THEN 3
            ELSE 0
        END) +
        CASE
            WHEN (("eo"."do_not_use_as" IS NULL) OR ("length"(TRIM(BOTH FROM "eo"."do_not_use_as")) < 40)) THEN 2
            ELSE 0
        END) +
        CASE
            WHEN (("eo"."curiosity_question" IS NULL) OR ("right"(TRIM(BOTH FROM "eo"."curiosity_question"), 1) <> '?'::"text")) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."source_traceability_status" IS DISTINCT FROM 'reviewed'::"text") THEN 2
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."close_paraphrase_risk" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) +
        CASE
            WHEN ("eo"."clinical_language_status" IS DISTINCT FROM 'cleared'::"text") THEN 3
            ELSE 0
        END) DESC, "eo"."source_id", "eo"."evidence_number";


ALTER VIEW "prism_audit"."raw_extraction_audit" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_audit"."deep_refinement_queue" AS
 SELECT "pcla"."evidence_id",
    "pcla"."source_id",
    "pcla"."source_title",
    "pcla"."concept_zone",
    "pcla"."public_title",
    "pcla"."public_finding",
    "pcla"."public_boundary",
    "pcla"."public_framework_application",
    "pcla"."public_open_question",
    "pcla"."source_supports",
    "pcla"."source_does_not_establish",
    "pcla"."evidence_role",
    "pcla"."source_role",
    "pcla"."confidence_level",
    "pcla"."uncertainty_flag",
    "pcla"."risk_category",
    "pcla"."audit_flags" AS "public_card_flags",
    "pcla"."audit_score" AS "public_card_score",
    "pcla"."next_card_action",
    "rea"."source_anchor",
    "rea"."source_linked_finding",
    "rea"."numeric_result",
    "rea"."author_interpretation",
    "rea"."evidence_boundary" AS "raw_evidence_boundary",
    "rea"."prism_use",
    "rea"."do_not_use_as",
    "rea"."curiosity_question" AS "raw_curiosity_question",
    "rea"."audit_flags" AS "raw_extraction_flags",
    "rea"."audit_score" AS "raw_extraction_score",
    ("pcla"."audit_score" + "rea"."audit_score") AS "combined_audit_score"
   FROM ("prism_audit"."public_card_language_audit" "pcla"
     LEFT JOIN "prism_audit"."raw_extraction_audit" "rea" ON (("rea"."evidence_id" = "pcla"."evidence_id")))
  ORDER BY ("pcla"."audit_score" + "rea"."audit_score") DESC NULLS LAST, "pcla"."source_title", "pcla"."evidence_id";


ALTER VIEW "prism_audit"."deep_refinement_queue" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_audit"."source_review_queue" AS
 SELECT "s"."source_id",
    "s"."title",
    "s"."citation",
    "s"."doi",
    "s"."journal",
    "s"."year",
    "s"."source_type",
    "s"."population_scope",
    "s"."design_label",
    "s"."source_review_status",
    "s"."provenance_status",
    "s"."access_rights_status",
    "s"."source_role",
    "s"."source_role_rationale",
    "count"(DISTINCT "eo"."evidence_id") AS "raw_evidence_object_count",
    "count"(DISTINCT "pec"."evidence_id") AS "curated_card_count",
    "count"(DISTINCT
        CASE
            WHEN ("pec"."risk_category" ~~* '%high%'::"text") THEN "pec"."evidence_id"
            ELSE NULL::"text"
        END) AS "high_risk_card_count",
    "count"(DISTINCT
        CASE
            WHEN ("pec"."risk_category" ~~* '%moderate%'::"text") THEN "pec"."evidence_id"
            ELSE NULL::"text"
        END) AS "moderate_risk_card_count",
        CASE
            WHEN ("s"."source_role" IS NULL) THEN 'needs_source_role'::"text"
            WHEN ("s"."source_review_status" IS DISTINCT FROM 'reviewed'::"text") THEN 'needs_source_review'::"text"
            WHEN ("s"."provenance_status" IS DISTINCT FROM 'reviewed'::"text") THEN 'needs_provenance_review'::"text"
            WHEN ("s"."access_rights_status" IS DISTINCT FROM 'cleared'::"text") THEN 'needs_access_rights_review'::"text"
            ELSE 'source_ready_for_card_review'::"text"
        END AS "next_source_action"
   FROM (("public"."sources" "s"
     LEFT JOIN "public"."evidence_objects" "eo" ON (("eo"."source_id" = "s"."source_id")))
     LEFT JOIN "public"."prism_evidence_curation" "pec" ON (("pec"."evidence_id" = "eo"."evidence_id")))
  GROUP BY "s"."source_id", "s"."title", "s"."citation", "s"."doi", "s"."journal", "s"."year", "s"."source_type", "s"."population_scope", "s"."design_label", "s"."source_review_status", "s"."provenance_status", "s"."access_rights_status", "s"."source_role", "s"."source_role_rationale"
  ORDER BY ("count"(DISTINCT
        CASE
            WHEN ("pec"."risk_category" ~~* '%high%'::"text") THEN "pec"."evidence_id"
            ELSE NULL::"text"
        END)) DESC, ("count"(DISTINCT
        CASE
            WHEN ("pec"."risk_category" ~~* '%moderate%'::"text") THEN "pec"."evidence_id"
            ELSE NULL::"text"
        END)) DESC, ("count"(DISTINCT "pec"."evidence_id")) DESC, "s"."year" DESC;


ALTER VIEW "prism_audit"."source_review_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_card_api_v01" (
    "ui_order" bigint NOT NULL,
    "release_id" "text" NOT NULL,
    "concept_zone" "text" NOT NULL,
    "title" "text" NOT NULL,
    "learner_hook" "text" NOT NULL,
    "plain_language_takeaway" "text" NOT NULL,
    "finding" "text" NOT NULL,
    "evidence_boundary" "text" NOT NULL,
    "framework_application" "text" NOT NULL,
    "misconception_to_avoid" "text" NOT NULL,
    "curiosity_question" "text" NOT NULL,
    "student_confidence_prompt" "text" NOT NULL,
    "source_title" "text" NOT NULL,
    "citation" "text" NOT NULL,
    "doi" "text" NOT NULL,
    "source_safety_note" "text",
    "read_original_source_prompt" "text",
    "card_size" "text",
    "card_role" "text",
    "visual_weight" integer,
    "reveal_style" "text"
);


ALTER TABLE "prism_core"."app_acl_rts_card_api_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_card_bridge_api_v01" (
    "bridge_order" integer NOT NULL,
    "release_id" "text" DEFAULT 'acl_rts_mvp_v0_1'::"text" NOT NULL,
    "from_ui_order" integer NOT NULL,
    "to_ui_order" integer NOT NULL,
    "bridge_type" "text" NOT NULL,
    "bridge_label" "text" NOT NULL,
    "student_bridge_explanation" "text" NOT NULL,
    "boundary_note" "text" NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_card_bridge_api_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_card_tag_map_v01" (
    "ui_order" integer NOT NULL,
    "tag_id" "text" NOT NULL,
    "tag_strength" integer DEFAULT 1 NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_card_tag_map_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_card_relation_scores_v01" AS
 WITH "shared_tags" AS (
         SELECT "a"."ui_order" AS "from_ui_order",
            "b"."ui_order" AS "to_ui_order",
            "count"(*) AS "shared_tag_count",
            "sum"(LEAST("a"."tag_strength", "b"."tag_strength")) AS "shared_tag_strength"
           FROM ("prism_core"."app_acl_rts_card_tag_map_v01" "a"
             JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "b" ON ((("b"."tag_id" = "a"."tag_id") AND ("b"."ui_order" <> "a"."ui_order"))))
          GROUP BY "a"."ui_order", "b"."ui_order"
        ), "bridge_links" AS (
         SELECT "app_acl_rts_card_bridge_api_v01"."from_ui_order",
            "app_acl_rts_card_bridge_api_v01"."to_ui_order",
            1 AS "explicit_bridge"
           FROM "prism_core"."app_acl_rts_card_bridge_api_v01"
        UNION ALL
         SELECT "app_acl_rts_card_bridge_api_v01"."to_ui_order" AS "from_ui_order",
            "app_acl_rts_card_bridge_api_v01"."from_ui_order" AS "to_ui_order",
            1 AS "explicit_bridge"
           FROM "prism_core"."app_acl_rts_card_bridge_api_v01"
        )
 SELECT "from_card"."ui_order" AS "from_ui_order",
    "from_card"."title" AS "from_title",
    "from_card"."concept_zone" AS "from_concept_zone",
    "to_card"."ui_order" AS "to_ui_order",
    "to_card"."title" AS "to_title",
    "to_card"."concept_zone" AS "to_concept_zone",
    COALESCE("st"."shared_tag_count", (0)::bigint) AS "shared_tag_count",
    COALESCE("st"."shared_tag_strength", (0)::bigint) AS "shared_tag_strength",
    COALESCE("max"("bl"."explicit_bridge"), 0) AS "explicit_bridge",
    ((COALESCE("st"."shared_tag_strength", (0)::bigint) +
        CASE
            WHEN ("max"("bl"."explicit_bridge") = 1) THEN 5
            ELSE 0
        END) +
        CASE
            WHEN ("from_card"."concept_zone" <> "to_card"."concept_zone") THEN 1
            ELSE 0
        END) AS "relation_score",
        CASE
            WHEN ("max"("bl"."explicit_bridge") = 1) THEN 'explicit_concept_bridge'::"text"
            WHEN (COALESCE("st"."shared_tag_strength", (0)::bigint) >= 4) THEN 'strong_shared_concept'::"text"
            WHEN (COALESCE("st"."shared_tag_strength", (0)::bigint) >= 2) THEN 'related_concept'::"text"
            ELSE 'weak_relation'::"text"
        END AS "relation_type"
   FROM ((("prism_core"."app_acl_rts_card_api_v01" "from_card"
     JOIN "prism_core"."app_acl_rts_card_api_v01" "to_card" ON (("to_card"."ui_order" <> "from_card"."ui_order")))
     LEFT JOIN "shared_tags" "st" ON ((("st"."from_ui_order" = "from_card"."ui_order") AND ("st"."to_ui_order" = "to_card"."ui_order"))))
     LEFT JOIN "bridge_links" "bl" ON ((("bl"."from_ui_order" = "from_card"."ui_order") AND ("bl"."to_ui_order" = "to_card"."ui_order"))))
  GROUP BY "from_card"."ui_order", "from_card"."title", "from_card"."concept_zone", "to_card"."ui_order", "to_card"."title", "to_card"."concept_zone", "st"."shared_tag_count", "st"."shared_tag_strength"
  ORDER BY "from_card"."ui_order", ((COALESCE("st"."shared_tag_strength", (0)::bigint) +
        CASE
            WHEN ("max"("bl"."explicit_bridge") = 1) THEN 5
            ELSE 0
        END) +
        CASE
            WHEN ("from_card"."concept_zone" <> "to_card"."concept_zone") THEN 1
            ELSE 0
        END) DESC, "to_card"."ui_order";


ALTER VIEW "prism_core"."app_acl_rts_card_relation_scores_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_next_best_cards_v01" AS
 SELECT "from_ui_order",
    "from_title",
    "from_concept_zone",
    "to_ui_order",
    "to_title",
    "to_concept_zone",
    "relation_score",
    "relation_type",
    "recommendation_rank"
   FROM ( SELECT "app_acl_rts_card_relation_scores_v01"."from_ui_order",
            "app_acl_rts_card_relation_scores_v01"."from_title",
            "app_acl_rts_card_relation_scores_v01"."from_concept_zone",
            "app_acl_rts_card_relation_scores_v01"."to_ui_order",
            "app_acl_rts_card_relation_scores_v01"."to_title",
            "app_acl_rts_card_relation_scores_v01"."to_concept_zone",
            "app_acl_rts_card_relation_scores_v01"."relation_score",
            "app_acl_rts_card_relation_scores_v01"."relation_type",
            "row_number"() OVER (PARTITION BY "app_acl_rts_card_relation_scores_v01"."from_ui_order" ORDER BY "app_acl_rts_card_relation_scores_v01"."relation_score" DESC, "app_acl_rts_card_relation_scores_v01"."to_ui_order") AS "recommendation_rank"
           FROM "prism_core"."app_acl_rts_card_relation_scores_v01"
          WHERE ("app_acl_rts_card_relation_scores_v01"."relation_score" > 0)) "ranked"
  WHERE ("recommendation_rank" <= 3)
  ORDER BY "from_ui_order", "recommendation_rank";


ALTER VIEW "prism_core"."app_acl_rts_next_best_cards_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_card_energy_profile_v01" AS
 SELECT "c"."ui_order",
    "c"."title",
    "c"."concept_zone",
    "count"(DISTINCT "m"."tag_id") AS "tag_count",
    COALESCE("sum"("m"."tag_strength"), (0)::bigint) AS "total_concept_strength",
    ("count"(DISTINCT "b1"."bridge_order") + "count"(DISTINCT "b2"."bridge_order")) AS "bridge_connection_count",
    "count"(DISTINCT "nb"."to_ui_order") AS "next_best_count",
        CASE
            WHEN ("c"."ui_order" = ANY (ARRAY[(1)::bigint, (9)::bigint, (11)::bigint])) THEN 'anchor_energy'::"text"
            WHEN (("count"(DISTINCT "b1"."bridge_order") + "count"(DISTINCT "b2"."bridge_order")) >= 2) THEN 'connector_energy'::"text"
            WHEN (COALESCE("sum"("m"."tag_strength"), (0)::bigint) >= 5) THEN 'concept_density_energy'::"text"
            ELSE 'supporting_energy'::"text"
        END AS "energy_role",
        CASE
            WHEN ("c"."concept_zone" = 'Return-to-Sport Uncertainty'::"text") THEN 'This card helps organize uncertainty.'::"text"
            WHEN ("c"."concept_zone" = 'Second Injury Risk'::"text") THEN 'This card helps contain risk interpretation.'::"text"
            WHEN ("c"."concept_zone" = 'Measurement and Testing'::"text") THEN 'This card helps clarify measurement assumptions.'::"text"
            ELSE 'This card supports the map.'::"text"
        END AS "student_energy_explanation"
   FROM (((("prism_core"."app_acl_rts_card_api_v01" "c"
     LEFT JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "m" ON (("m"."ui_order" = "c"."ui_order")))
     LEFT JOIN "prism_core"."app_acl_rts_card_bridge_api_v01" "b1" ON (("b1"."from_ui_order" = "c"."ui_order")))
     LEFT JOIN "prism_core"."app_acl_rts_card_bridge_api_v01" "b2" ON (("b2"."to_ui_order" = "c"."ui_order")))
     LEFT JOIN "prism_core"."app_acl_rts_next_best_cards_v01" "nb" ON (("nb"."from_ui_order" = "c"."ui_order")))
  GROUP BY "c"."ui_order", "c"."title", "c"."concept_zone"
  ORDER BY "c"."ui_order";


ALTER VIEW "prism_core"."app_acl_rts_card_energy_profile_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_card_presentation_v01" (
    "ui_order" integer NOT NULL,
    "card_size" "text" NOT NULL,
    "card_role" "text" NOT NULL,
    "visual_weight" integer NOT NULL,
    "reveal_style" "text" NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_card_presentation_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_section_layout_v01" AS
 SELECT "c"."concept_zone",
    "min"("c"."ui_order") AS "first_card_order",
    "count"(*) AS "card_count",
    "max"(
        CASE
            WHEN ("p"."card_size" = 'feature'::"text") THEN "c"."title"
            ELSE NULL::"text"
        END) AS "featured_card_title",
        CASE "c"."concept_zone"
            WHEN 'Return-to-Sport Uncertainty'::"text" THEN 'Start here. RTS is not one clean outcome.'::"text"
            WHEN 'Second Injury Risk'::"text" THEN 'Risk signals matter, but they are not prediction certainty.'::"text"
            WHEN 'Measurement and Testing'::"text" THEN 'Measures help, but every measure has assumptions.'::"text"
            ELSE 'Evidence section'::"text"
        END AS "section_intro",
        CASE "c"."concept_zone"
            WHEN 'Return-to-Sport Uncertainty'::"text" THEN 'Outcome language, usual-care context, criteria limits, and psychological readiness.'::"text"
            WHEN 'Second Injury Risk'::"text" THEN 'Timing and test findings as population-level risk signals.'::"text"
            WHEN 'Measurement and Testing'::"text" THEN 'Symmetry, LSI, and the limits of measurement confidence.'::"text"
            ELSE 'Source-linked evidence cards.'::"text"
        END AS "section_subtitle",
        CASE "c"."concept_zone"
            WHEN 'Return-to-Sport Uncertainty'::"text" THEN 'What does “return” actually mean in this source?'::"text"
            WHEN 'Second Injury Risk'::"text" THEN 'What does this risk signal support, and where does it stop?'::"text"
            WHEN 'Measurement and Testing'::"text" THEN 'What does this measure show, and what might it miss?'::"text"
            ELSE 'What question does this evidence raise?'::"text"
        END AS "section_guiding_question"
   FROM ("prism_core"."app_acl_rts_card_api_v01" "c"
     JOIN "prism_core"."app_acl_rts_card_presentation_v01" "p" ON (("p"."ui_order" = "c"."ui_order")))
  GROUP BY "c"."concept_zone"
  ORDER BY ("min"("c"."ui_order"));


ALTER VIEW "prism_core"."app_acl_rts_section_layout_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_composed_ui_v01" AS
 SELECT "c"."ui_order",
    "c"."release_id",
    "c"."concept_zone",
    "l"."section_intro",
    "l"."section_subtitle",
    "l"."section_guiding_question",
    "p"."card_size",
    "p"."card_role",
    "p"."visual_weight",
    "p"."reveal_style",
    "c"."title",
    "c"."learner_hook",
    "c"."plain_language_takeaway",
    "c"."finding",
    "c"."evidence_boundary",
    "c"."framework_application",
    "c"."misconception_to_avoid",
    "c"."curiosity_question",
    "c"."student_confidence_prompt",
    "c"."source_title",
    "c"."citation",
    "c"."doi",
    "c"."source_safety_note",
    "c"."read_original_source_prompt"
   FROM (("prism_core"."app_acl_rts_card_api_v01" "c"
     JOIN "prism_core"."app_acl_rts_card_presentation_v01" "p" ON (("p"."ui_order" = "c"."ui_order")))
     JOIN "prism_core"."app_acl_rts_section_layout_v01" "l" ON (("l"."concept_zone" = "c"."concept_zone")))
  ORDER BY "c"."ui_order";


ALTER VIEW "prism_core"."app_acl_rts_composed_ui_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_concept_tag_api_v01" (
    "tag_id" "text" NOT NULL,
    "tag_label" "text" NOT NULL,
    "tag_type" "text" NOT NULL,
    "student_meaning" "text" NOT NULL,
    "design_instruction" "text" NOT NULL,
    "boundary_note" "text" NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_concept_tag_api_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_advanced_map_payload_v01" AS
 SELECT "c"."ui_order",
    "c"."release_id",
    "c"."concept_zone",
    "c"."section_intro",
    "c"."section_subtitle",
    "c"."section_guiding_question",
    "c"."card_size",
    "c"."card_role",
    "c"."visual_weight",
    "c"."reveal_style",
    "e"."energy_role",
    "e"."total_concept_strength",
    "e"."bridge_connection_count",
    "e"."next_best_count",
    "e"."student_energy_explanation",
    "c"."title",
    "c"."learner_hook",
    "c"."plain_language_takeaway",
    "c"."finding",
    "c"."evidence_boundary",
    "c"."framework_application",
    "c"."misconception_to_avoid",
    "c"."curiosity_question",
    "c"."student_confidence_prompt",
    "array_agg"(DISTINCT "t"."tag_label" ORDER BY "t"."tag_label") AS "concept_tags",
    "array_agg"(DISTINCT "t"."student_meaning" ORDER BY "t"."student_meaning") AS "concept_meanings",
    "c"."source_title",
    "c"."citation",
    "c"."doi",
    "c"."source_safety_note",
    "c"."read_original_source_prompt"
   FROM ((("prism_core"."app_acl_rts_composed_ui_v01" "c"
     LEFT JOIN "prism_core"."app_acl_rts_card_energy_profile_v01" "e" ON (("e"."ui_order" = "c"."ui_order")))
     LEFT JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "m" ON (("m"."ui_order" = "c"."ui_order")))
     LEFT JOIN "prism_core"."app_acl_rts_concept_tag_api_v01" "t" ON (("t"."tag_id" = "m"."tag_id")))
  GROUP BY "c"."ui_order", "c"."release_id", "c"."concept_zone", "c"."section_intro", "c"."section_subtitle", "c"."section_guiding_question", "c"."card_size", "c"."card_role", "c"."visual_weight", "c"."reveal_style", "e"."energy_role", "e"."total_concept_strength", "e"."bridge_connection_count", "e"."next_best_count", "e"."student_energy_explanation", "c"."title", "c"."learner_hook", "c"."plain_language_takeaway", "c"."finding", "c"."evidence_boundary", "c"."framework_application", "c"."misconception_to_avoid", "c"."curiosity_question", "c"."student_confidence_prompt", "c"."source_title", "c"."citation", "c"."doi", "c"."source_safety_note", "c"."read_original_source_prompt"
  ORDER BY "c"."ui_order";


ALTER VIEW "prism_core"."app_acl_rts_advanced_map_payload_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_source_api_v01" (
    "source_order" bigint NOT NULL,
    "source_title" "text" NOT NULL,
    "citation" "text" NOT NULL,
    "doi" "text" NOT NULL,
    "journal" "text" NOT NULL,
    "year" "text" NOT NULL,
    "source_type" "text" NOT NULL,
    "locked_source_role" "text" NOT NULL,
    "card_count" bigint NOT NULL,
    "represented_concept_zones" "text",
    "source_note" "text" NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_source_api_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_api_health_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_card_api_v01") AS "card_api_rows",
    ( SELECT "count"(DISTINCT "app_acl_rts_card_api_v01"."ui_order") AS "count"
           FROM "prism_core"."app_acl_rts_card_api_v01") AS "unique_card_orders",
    ( SELECT "count"(DISTINCT "app_acl_rts_card_api_v01"."concept_zone") AS "count"
           FROM "prism_core"."app_acl_rts_card_api_v01") AS "card_concept_zones",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_api_rows",
    ( SELECT "sum"("app_acl_rts_source_api_v01"."card_count") AS "sum"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_cards_represented",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_card_api_v01"
          WHERE (("app_acl_rts_card_api_v01"."title" IS NULL) OR ("app_acl_rts_card_api_v01"."learner_hook" IS NULL) OR ("app_acl_rts_card_api_v01"."plain_language_takeaway" IS NULL) OR ("app_acl_rts_card_api_v01"."finding" IS NULL) OR ("app_acl_rts_card_api_v01"."evidence_boundary" IS NULL) OR ("app_acl_rts_card_api_v01"."framework_application" IS NULL) OR ("app_acl_rts_card_api_v01"."misconception_to_avoid" IS NULL) OR ("app_acl_rts_card_api_v01"."curiosity_question" IS NULL) OR ("app_acl_rts_card_api_v01"."student_confidence_prompt" IS NULL) OR ("app_acl_rts_card_api_v01"."citation" IS NULL) OR ("app_acl_rts_card_api_v01"."doi" IS NULL))) AS "card_missing_required_fields",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_api_v01"
          WHERE (("app_acl_rts_source_api_v01"."source_title" IS NULL) OR ("app_acl_rts_source_api_v01"."citation" IS NULL) OR ("app_acl_rts_source_api_v01"."doi" IS NULL) OR ("app_acl_rts_source_api_v01"."journal" IS NULL) OR ("app_acl_rts_source_api_v01"."year" IS NULL) OR ("app_acl_rts_source_api_v01"."source_type" IS NULL) OR ("app_acl_rts_source_api_v01"."locked_source_role" IS NULL) OR ("app_acl_rts_source_api_v01"."source_note" IS NULL))) AS "source_missing_required_fields",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_card_api_v01"
          WHERE (("app_acl_rts_card_api_v01"."finding" ~~* '%patient should%'::"text") OR ("app_acl_rts_card_api_v01"."finding" ~~* '%clinician should%'::"text") OR ("app_acl_rts_card_api_v01"."finding" ~~* '%progress when%'::"text") OR ("app_acl_rts_card_api_v01"."finding" ~~* '%protocol%'::"text") OR ("app_acl_rts_card_api_v01"."evidence_boundary" ~~* '%patient should%'::"text") OR ("app_acl_rts_card_api_v01"."evidence_boundary" ~~* '%clinician should%'::"text") OR ("app_acl_rts_card_api_v01"."evidence_boundary" ~~* '%progress when%'::"text") OR ("app_acl_rts_card_api_v01"."evidence_boundary" ~~* '%protocol%'::"text") OR ("app_acl_rts_card_api_v01"."framework_application" ~~* '%patient should%'::"text") OR ("app_acl_rts_card_api_v01"."framework_application" ~~* '%clinician should%'::"text") OR ("app_acl_rts_card_api_v01"."framework_application" ~~* '%progress when%'::"text") OR ("app_acl_rts_card_api_v01"."framework_application" ~~* '%protocol%'::"text") OR ("app_acl_rts_card_api_v01"."plain_language_takeaway" ~~* '%patient should%'::"text") OR ("app_acl_rts_card_api_v01"."plain_language_takeaway" ~~* '%clinician should%'::"text") OR ("app_acl_rts_card_api_v01"."plain_language_takeaway" ~~* '%progress when%'::"text") OR ("app_acl_rts_card_api_v01"."plain_language_takeaway" ~~* '%protocol%'::"text"))) AS "clinical_language_risk_count",
    "now"() AS "checked_at";


ALTER VIEW "prism_core"."app_acl_rts_api_health_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_bridge_public_v01" AS
 SELECT "b"."bridge_order",
    "b"."release_id",
    "b"."bridge_type",
    "b"."bridge_label",
    "b"."from_ui_order",
    "from_card"."title" AS "from_card_title",
    "from_card"."concept_zone" AS "from_concept_zone",
    "b"."to_ui_order",
    "to_card"."title" AS "to_card_title",
    "to_card"."concept_zone" AS "to_concept_zone",
    "b"."student_bridge_explanation",
    "b"."boundary_note"
   FROM (("prism_core"."app_acl_rts_card_bridge_api_v01" "b"
     JOIN "prism_core"."app_acl_rts_card_api_v01" "from_card" ON (("from_card"."ui_order" = "b"."from_ui_order")))
     JOIN "prism_core"."app_acl_rts_card_api_v01" "to_card" ON (("to_card"."ui_order" = "b"."to_ui_order")))
  ORDER BY "b"."bridge_order";


ALTER VIEW "prism_core"."app_acl_rts_bridge_public_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_card_backlinks_v01" AS
 SELECT "c"."ui_order",
    "c"."title",
    "c"."concept_zone",
    "t"."tag_id",
    "t"."tag_label",
    "t"."tag_type",
    "t"."student_meaning",
    "t"."design_instruction",
    "array_agg"("related"."title" ORDER BY "related"."ui_order") FILTER (WHERE ("related"."ui_order" <> "c"."ui_order")) AS "related_cards"
   FROM (((("prism_core"."app_acl_rts_card_api_v01" "c"
     JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "m" ON (("m"."ui_order" = "c"."ui_order")))
     JOIN "prism_core"."app_acl_rts_concept_tag_api_v01" "t" ON (("t"."tag_id" = "m"."tag_id")))
     JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "rm" ON (("rm"."tag_id" = "m"."tag_id")))
     JOIN "prism_core"."app_acl_rts_card_api_v01" "related" ON (("related"."ui_order" = "rm"."ui_order")))
  GROUP BY "c"."ui_order", "c"."title", "c"."concept_zone", "t"."tag_id", "t"."tag_label", "t"."tag_type", "t"."student_meaning", "t"."design_instruction"
  ORDER BY "c"."ui_order", "t"."tag_label";


ALTER VIEW "prism_core"."app_acl_rts_card_backlinks_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_concept_constellation_api_v01" AS
 SELECT "t"."tag_id",
    "t"."tag_label",
    "t"."tag_type",
    "t"."student_meaning",
    "t"."design_instruction",
    "t"."boundary_note",
    "count"(DISTINCT "m"."ui_order") AS "card_count",
    "array_agg"(DISTINCT "c"."title" ORDER BY "c"."title") AS "connected_cards",
    "array_agg"(DISTINCT "c"."concept_zone" ORDER BY "c"."concept_zone") AS "concept_zones",
    "array_agg"(DISTINCT "c"."source_title" ORDER BY "c"."source_title") AS "source_titles",
    COALESCE("sum"("m"."tag_strength"), (0)::bigint) AS "total_tag_strength",
        CASE
            WHEN (COALESCE("sum"("m"."tag_strength"), (0)::bigint) >= 8) THEN 'high_signal'::"text"
            WHEN (COALESCE("sum"("m"."tag_strength"), (0)::bigint) >= 5) THEN 'medium_signal'::"text"
            ELSE 'supporting_signal'::"text"
        END AS "constellation_strength",
        CASE
            WHEN ("t"."tag_type" = 'framework_tag'::"text") THEN 'Use as a map-organizing concept.'::"text"
            WHEN ("t"."tag_type" = 'gap_tag'::"text") THEN 'Use as an uncertainty or missing-domain reveal.'::"text"
            WHEN ("t"."tag_type" = 'boundary_tag'::"text") THEN 'Use as a caution or evidence-boundary reveal.'::"text"
            WHEN ("t"."tag_type" = 'context_tag'::"text") THEN 'Use as a real-world decision-ecology layer.'::"text"
            ELSE 'Use as a supporting concept.'::"text"
        END AS "ui_behavior"
   FROM (("prism_core"."app_acl_rts_concept_tag_api_v01" "t"
     LEFT JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "m" ON (("m"."tag_id" = "t"."tag_id")))
     LEFT JOIN "prism_core"."app_acl_rts_card_api_v01" "c" ON (("c"."ui_order" = "m"."ui_order")))
  GROUP BY "t"."tag_id", "t"."tag_label", "t"."tag_type", "t"."student_meaning", "t"."design_instruction", "t"."boundary_note"
  ORDER BY COALESCE("sum"("m"."tag_strength"), (0)::bigint) DESC, "t"."tag_label";


ALTER VIEW "prism_core"."app_acl_rts_concept_constellation_api_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_design_instruction_payload_v01" AS
 SELECT "c"."ui_order",
    "c"."concept_zone",
    "c"."title",
    "c"."learner_hook",
    "c"."plain_language_takeaway",
    "c"."finding",
    "c"."evidence_boundary",
    "c"."framework_application",
    "c"."curiosity_question",
    "array_agg"(DISTINCT "t"."tag_label" ORDER BY "t"."tag_label") AS "concept_tags",
    "array_agg"(DISTINCT "t"."student_meaning" ORDER BY "t"."student_meaning") AS "student_meanings",
    "array_agg"(DISTINCT "t"."design_instruction" ORDER BY "t"."design_instruction") AS "design_instructions",
        CASE
            WHEN "bool_or"(("t"."tag_id" = 'rts_language_precision'::"text")) THEN 'Show this as an outcome-language clarification card.'::"text"
            WHEN "bool_or"(("t"."tag_id" = 'risk_signal_not_rule'::"text")) THEN 'Show this as a risk-boundary card.'::"text"
            WHEN "bool_or"(("t"."tag_id" = 'measurement_limits'::"text")) THEN 'Show this as a measurement-lens card.'::"text"
            WHEN "bool_or"(("t"."tag_id" = 'psychological_readiness_gap'::"text")) THEN 'Show this as a missing-domain card.'::"text"
            WHEN "bool_or"(("t"."tag_id" = 'decision_ecology'::"text")) THEN 'Show this as a context/ecology card.'::"text"
            ELSE 'Show this as a standard evidence card.'::"text"
        END AS "primary_ui_instruction"
   FROM (("prism_core"."app_acl_rts_card_api_v01" "c"
     LEFT JOIN "prism_core"."app_acl_rts_card_tag_map_v01" "m" ON (("m"."ui_order" = "c"."ui_order")))
     LEFT JOIN "prism_core"."app_acl_rts_concept_tag_api_v01" "t" ON (("t"."tag_id" = "m"."tag_id")))
  GROUP BY "c"."ui_order", "c"."concept_zone", "c"."title", "c"."learner_hook", "c"."plain_language_takeaway", "c"."finding", "c"."evidence_boundary", "c"."framework_application", "c"."curiosity_question"
  ORDER BY "c"."ui_order";


ALTER VIEW "prism_core"."app_acl_rts_design_instruction_payload_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_learning_path_cards_v01" (
    "path_id" "text" NOT NULL,
    "path_step" integer NOT NULL,
    "ui_order" integer NOT NULL,
    "step_label" "text" NOT NULL,
    "step_reason" "text" NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_learning_path_cards_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_learning_paths_v01" (
    "path_id" "text" NOT NULL,
    "release_id" "text" DEFAULT 'acl_rts_mvp_v0_1'::"text" NOT NULL,
    "path_order" integer NOT NULL,
    "path_title" "text" NOT NULL,
    "path_frame" "text" NOT NULL,
    "student_use_case" "text" NOT NULL,
    "boundary_note" "text" NOT NULL
);


ALTER TABLE "prism_core"."app_acl_rts_learning_paths_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_learning_path_api_v01" AS
 SELECT "p"."path_order",
    "p"."path_id",
    "p"."path_title",
    "p"."path_frame",
    "p"."student_use_case",
    "p"."boundary_note" AS "path_boundary_note",
    "pc"."path_step",
    "pc"."step_label",
    "pc"."step_reason",
    "c"."ui_order",
    "c"."concept_zone",
    "c"."title",
    "c"."learner_hook",
    "c"."plain_language_takeaway",
    "c"."finding",
    "c"."evidence_boundary",
    "c"."framework_application",
    "c"."curiosity_question",
    "c"."source_title",
    "c"."doi"
   FROM (("prism_core"."app_acl_rts_learning_paths_v01" "p"
     JOIN "prism_core"."app_acl_rts_learning_path_cards_v01" "pc" ON (("pc"."path_id" = "p"."path_id")))
     JOIN "prism_core"."app_acl_rts_card_api_v01" "c" ON (("c"."ui_order" = "pc"."ui_order")))
  ORDER BY "p"."path_order", "pc"."path_step";


ALTER VIEW "prism_core"."app_acl_rts_learning_path_api_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."source_registry_locked" (
    "source_id" "text",
    "title" "text",
    "citation" "text",
    "doi" "text",
    "journal" "text",
    "year" "text",
    "source_type" "text",
    "population_scope" "text",
    "design_label" "text",
    "locked_source_role" "text",
    "prism_role_rationale" "text",
    "include_status" "text",
    "provenance_status" "text",
    "access_rights_status" "text",
    "registry_status" "text",
    "locked_at" timestamp with time zone
);


ALTER TABLE "prism_core"."source_registry_locked" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_editor"."mvp_candidate_cards_12" (
    "evidence_id" "text",
    "source_id" "text",
    "locked_source_role" "text",
    "prism_role_rationale" "text",
    "concept_zone_id" "text",
    "concept_zone_display" "text",
    "title" "text",
    "finding" "text",
    "evidence_boundary" "text",
    "framework_application" "text",
    "curiosity_question" "text",
    "blocked_language_flag" boolean,
    "replacement_risk_flag" boolean,
    "audit_score" integer,
    "mvp_status" "text",
    "selected_at" timestamp with time zone
);


ALTER TABLE "prism_editor"."mvp_candidate_cards_12" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_editor"."mvp_card_rewrites_12" (
    "evidence_id" "text" NOT NULL,
    "revised_title" "text" NOT NULL,
    "revised_finding" "text" NOT NULL,
    "revised_evidence_boundary" "text" NOT NULL,
    "revised_framework_application" "text" NOT NULL,
    "revised_curiosity_question" "text" NOT NULL,
    "rewrite_status" "text" DEFAULT 'draft_needs_human_review'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "prism_editor"."mvp_card_rewrites_12" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."mvp_public_cards_12" AS
 SELECT "r"."evidence_id",
    "m"."source_id",
    "sr"."title" AS "source_title",
    "sr"."citation",
    "sr"."doi",
    "sr"."journal",
    "sr"."year",
    "sr"."source_type",
    "sr"."locked_source_role",
    "m"."concept_zone_id",
    "m"."concept_zone_display" AS "concept_zone",
    "r"."revised_title" AS "title",
    "r"."revised_finding" AS "finding",
    "r"."revised_evidence_boundary" AS "evidence_boundary",
    "r"."revised_framework_application" AS "framework_application",
    "r"."revised_curiosity_question" AS "curiosity_question",
    'Source-linked educational framework. Not a replacement for the original article.'::"text" AS "source_safety_note",
    'Read the original source for full methods, results, and author interpretation.'::"text" AS "read_original_source_prompt"
   FROM (("prism_editor"."mvp_card_rewrites_12" "r"
     JOIN "prism_editor"."mvp_candidate_cards_12" "m" ON (("m"."evidence_id" = "r"."evidence_id")))
     JOIN "prism_core"."source_registry_locked" "sr" ON (("sr"."source_id" = "m"."source_id")))
  WHERE ("r"."rewrite_status" = 'draft_needs_human_review'::"text");


ALTER VIEW "prism_core"."mvp_public_cards_12" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_mvp_cards" AS
 SELECT "evidence_id",
    "concept_zone",
    "title",
    "finding",
    "evidence_boundary",
    "framework_application",
    "curiosity_question",
    "source_title",
    "citation",
    "doi",
    "journal",
    "year",
    "source_type",
    "locked_source_role",
    "source_safety_note",
    "read_original_source_prompt"
   FROM "prism_core"."mvp_public_cards_12"
  ORDER BY
        CASE "concept_zone"
            WHEN 'Return-to-Sport Uncertainty'::"text" THEN 1
            WHEN 'Second Injury Risk'::"text" THEN 2
            WHEN 'Measurement and Testing'::"text" THEN 3
            ELSE 99
        END, "evidence_id";


ALTER VIEW "prism_core"."app_acl_rts_mvp_cards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_mvp_cards_v01" (
    "display_order" bigint,
    "release_id" "text" NOT NULL,
    "evidence_id" "text" NOT NULL,
    "concept_zone" "text" NOT NULL,
    "title" "text" NOT NULL,
    "finding" "text" NOT NULL,
    "evidence_boundary" "text" NOT NULL,
    "framework_application" "text" NOT NULL,
    "curiosity_question" "text" NOT NULL,
    "source_title" "text" NOT NULL,
    "citation" "text" NOT NULL,
    "doi" "text" NOT NULL,
    "journal" "text",
    "year" "text",
    "source_type" "text",
    "locked_source_role" "text",
    "source_safety_note" "text",
    "read_original_source_prompt" "text",
    "created_at" timestamp with time zone,
    "learner_hook" "text",
    "plain_language_takeaway" "text",
    "misconception_to_avoid" "text",
    "student_confidence_prompt" "text"
);


ALTER TABLE "prism_core"."app_acl_rts_mvp_cards_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_mvp_cards_v01_backup" (
    "display_order" bigint,
    "release_id" "text",
    "evidence_id" "text",
    "concept_zone" "text",
    "title" "text",
    "finding" "text",
    "evidence_boundary" "text",
    "framework_application" "text",
    "curiosity_question" "text",
    "source_title" "text",
    "citation" "text",
    "doi" "text",
    "journal" "text",
    "year" "text",
    "source_type" "text",
    "locked_source_role" "text",
    "source_safety_note" "text",
    "read_original_source_prompt" "text",
    "created_at" timestamp with time zone
);


ALTER TABLE "prism_core"."app_acl_rts_mvp_cards_v01_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_mvp_copy_v01" (
    "release_id" "text" NOT NULL,
    "eyebrow" "text" NOT NULL,
    "headline" "text" NOT NULL,
    "subheadline" "text" NOT NULL,
    "primary_boundary" "text" NOT NULL,
    "card_label_finding" "text" NOT NULL,
    "card_label_boundary" "text" NOT NULL,
    "card_label_framework" "text" NOT NULL,
    "card_label_curiosity" "text" NOT NULL,
    "source_label" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."app_acl_rts_mvp_copy_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_mvp_sections_v01" (
    "section_id" "text" NOT NULL,
    "release_id" "text" NOT NULL,
    "display_order" integer NOT NULL,
    "concept_zone" "text" NOT NULL,
    "section_title" "text" NOT NULL,
    "section_frame" "text" NOT NULL,
    "student_question" "text" NOT NULL,
    "boundary_note" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."app_acl_rts_mvp_sections_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_mvp_ui_payload_v01" AS
 SELECT "s"."release_id",
    "s"."display_order" AS "section_order",
    "s"."section_id",
    "s"."concept_zone",
    "s"."section_title",
    "s"."section_frame",
    "s"."student_question",
    "s"."boundary_note",
    "c"."display_order" AS "card_order",
    "c"."evidence_id",
    "c"."title",
    "c"."finding",
    "c"."evidence_boundary",
    "c"."framework_application",
    "c"."curiosity_question",
    "c"."source_title",
    "c"."citation",
    "c"."doi",
    "c"."journal",
    "c"."year",
    "c"."source_type",
    "c"."locked_source_role",
    "c"."source_safety_note",
    "c"."read_original_source_prompt"
   FROM ("prism_core"."app_acl_rts_mvp_sections_v01" "s"
     LEFT JOIN "prism_core"."app_acl_rts_mvp_cards_v01" "c" ON ((("c"."release_id" = "s"."release_id") AND ("c"."concept_zone" = "s"."concept_zone"))))
  ORDER BY "s"."display_order", "c"."display_order";


ALTER VIEW "prism_core"."app_acl_rts_mvp_ui_payload_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_student_payload_v01" (
    "ui_order" bigint,
    "display_order" bigint,
    "release_id" "text",
    "evidence_id" "text" NOT NULL,
    "concept_zone" "text",
    "title" "text",
    "learner_hook" "text",
    "plain_language_takeaway" "text",
    "finding" "text",
    "evidence_boundary" "text",
    "framework_application" "text",
    "misconception_to_avoid" "text",
    "curiosity_question" "text",
    "student_confidence_prompt" "text",
    "source_title" "text",
    "citation" "text",
    "doi" "text",
    "journal" "text",
    "year" "text",
    "source_type" "text",
    "locked_source_role" "text",
    "source_safety_note" "text",
    "read_original_source_prompt" "text",
    "created_at" timestamp with time zone,
    "section_sort_order" integer
);


ALTER TABLE "prism_core"."app_acl_rts_student_payload_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_student_payload_public_v01" AS
 SELECT "ui_order",
    "section_sort_order",
    "release_id",
    "concept_zone",
    "title",
    "learner_hook",
    "plain_language_takeaway",
    "finding",
    "evidence_boundary",
    "framework_application",
    "misconception_to_avoid",
    "curiosity_question",
    "student_confidence_prompt",
    "source_title",
    "citation",
    "doi",
    "journal",
    "year",
    "source_type",
    "locked_source_role",
    "source_safety_note",
    "read_original_source_prompt"
   FROM "prism_core"."app_acl_rts_student_payload_v01"
  ORDER BY "ui_order";


ALTER VIEW "prism_core"."app_acl_rts_student_payload_public_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_source_stack_public_v01" AS
 SELECT "source_title",
    "citation",
    "doi",
    "journal",
    "year",
    "source_type",
    "locked_source_role",
    "count"(*) AS "card_count",
    "string_agg"(DISTINCT "concept_zone", ', '::"text" ORDER BY "concept_zone") AS "represented_concept_zones",
    'Source-linked educational reference. Read the original source for full methods, results, and author interpretation.'::"text" AS "source_note"
   FROM "prism_core"."app_acl_rts_student_payload_public_v01"
  GROUP BY "source_title", "citation", "doi", "journal", "year", "source_type", "locked_source_role"
  ORDER BY
        CASE "locked_source_role"
            WHEN 'Anchor Source'::"text" THEN 1
            WHEN 'Primary Evidence Node'::"text" THEN 2
            WHEN 'Contrast Card'::"text" THEN 3
            ELSE 99
        END, "year" DESC, "source_title";


ALTER VIEW "prism_core"."app_acl_rts_source_stack_public_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_release_health_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_student_payload_public_v01") AS "public_card_count",
    ( SELECT "count"(DISTINCT "app_acl_rts_student_payload_public_v01"."source_title") AS "count"
           FROM "prism_core"."app_acl_rts_student_payload_public_v01") AS "active_source_count",
    ( SELECT "count"(DISTINCT "app_acl_rts_student_payload_public_v01"."concept_zone") AS "count"
           FROM "prism_core"."app_acl_rts_student_payload_public_v01") AS "concept_zone_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_student_payload_public_v01"
          WHERE (("app_acl_rts_student_payload_public_v01"."title" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."finding" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."evidence_boundary" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."framework_application" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."curiosity_question" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."learner_hook" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."plain_language_takeaway" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."misconception_to_avoid" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."student_confidence_prompt" IS NULL) OR ("app_acl_rts_student_payload_public_v01"."doi" IS NULL))) AS "missing_required_field_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_student_payload_public_v01"
          WHERE (("app_acl_rts_student_payload_public_v01"."finding" ~~* '%patient should%'::"text") OR ("app_acl_rts_student_payload_public_v01"."finding" ~~* '%clinician should%'::"text") OR ("app_acl_rts_student_payload_public_v01"."finding" ~~* '%progress when%'::"text") OR ("app_acl_rts_student_payload_public_v01"."finding" ~~* '%protocol%'::"text") OR ("app_acl_rts_student_payload_public_v01"."finding" ~~* '%clear for%'::"text") OR ("app_acl_rts_student_payload_public_v01"."evidence_boundary" ~~* '%patient should%'::"text") OR ("app_acl_rts_student_payload_public_v01"."evidence_boundary" ~~* '%clinician should%'::"text") OR ("app_acl_rts_student_payload_public_v01"."evidence_boundary" ~~* '%progress when%'::"text") OR ("app_acl_rts_student_payload_public_v01"."evidence_boundary" ~~* '%protocol%'::"text") OR ("app_acl_rts_student_payload_public_v01"."evidence_boundary" ~~* '%clear for%'::"text") OR ("app_acl_rts_student_payload_public_v01"."framework_application" ~~* '%patient should%'::"text") OR ("app_acl_rts_student_payload_public_v01"."framework_application" ~~* '%clinician should%'::"text") OR ("app_acl_rts_student_payload_public_v01"."framework_application" ~~* '%progress when%'::"text") OR ("app_acl_rts_student_payload_public_v01"."framework_application" ~~* '%protocol%'::"text") OR ("app_acl_rts_student_payload_public_v01"."framework_application" ~~* '%clear for%'::"text"))) AS "clinical_language_risk_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_stack_public_v01") AS "source_stack_count",
    "now"() AS "checked_at";


ALTER VIEW "prism_core"."app_acl_rts_release_health_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."app_acl_rts_release_manifest_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    'ACL RTS MVP v0.1'::"text" AS "release_name",
    'app_acl_rts_student_payload_public_v01'::"text" AS "public_card_view",
    'app_acl_rts_source_stack_public_v01'::"text" AS "source_stack_view",
    'app_acl_rts_student_payload_v01'::"text" AS "frozen_payload_table",
    'app_acl_rts_mvp_cards_v01'::"text" AS "frozen_evidence_table",
    'mvp_source_scope_v01'::"text" AS "source_scope_table",
    'mvp_release_status'::"text" AS "release_status_table",
    5 AS "active_source_count",
    12 AS "public_card_count",
    3 AS "concept_zone_count",
    'protected_by_update_delete_triggers'::"text" AS "payload_protection_status",
    'source-linked educational framework; not protocol, not RTS clearance, not clinical guidance'::"text" AS "boundary",
    "now"() AS "generated_at";


ALTER VIEW "prism_core"."app_acl_rts_release_manifest_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."app_acl_rts_student_payload_v01_audit_log" (
    "audit_id" bigint NOT NULL,
    "release_id" "text",
    "evidence_id" "text",
    "action" "text" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."app_acl_rts_student_payload_v01_audit_log" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "prism_core"."app_acl_rts_student_payload_v01_audit_log_audit_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "prism_core"."app_acl_rts_student_payload_v01_audit_log_audit_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "prism_core"."app_acl_rts_student_payload_v01_audit_log_audit_id_seq" OWNED BY "prism_core"."app_acl_rts_student_payload_v01_audit_log"."audit_id";



CREATE TABLE IF NOT EXISTS "prism_core"."concept_zones" (
    "concept_zone_id" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "boundary_rule" "text" NOT NULL,
    "student_psychology_frame" "text" NOT NULL,
    "sort_order" integer NOT NULL
);


ALTER TABLE "prism_core"."concept_zones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."database_visual_map_v01" (
    "map_id" "text" NOT NULL,
    "map_title" "text" NOT NULL,
    "mermaid_diagram" "text" NOT NULL,
    "plain_language_map" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."database_visual_map_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."evidence_cards" (
    "evidence_id" "text" NOT NULL,
    "source_id" "text",
    "source_title" "text",
    "source_citation" "text",
    "source_link" "text",
    "source_role" "text",
    "concept_zone_id" "text",
    "title" "text",
    "finding" "text",
    "evidence_boundary" "text",
    "framework_application" "text",
    "curiosity_question" "text",
    "source_supports" "text",
    "source_does_not_establish" "text",
    "numeric_result" "text",
    "source_anchor" "text",
    "author_interpretation" "text",
    "do_not_use_as" "text",
    "certainty_flag" "text",
    "object_role" "text",
    "risk_category" "text",
    "public_readiness_status" "text",
    "source_traceability_status" "text",
    "close_paraphrase_risk" "text",
    "clinical_language_status" "text",
    "approved_for_mvp" boolean,
    "blocked_language_flag" boolean,
    "replacement_risk_flag" boolean,
    "missing_field_flag" boolean,
    "long_card_flag" boolean,
    "original_concept_zone" "text",
    "raw_evidence_object" "jsonb",
    "raw_public_curation" "jsonb",
    "concept_zone_display" "text",
    "audit_score" integer
);


ALTER TABLE "prism_core"."evidence_cards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."mvp_release_status" (
    "release_id" "text" NOT NULL,
    "release_name" "text" NOT NULL,
    "app_table" "text" NOT NULL,
    "active_source_count" integer NOT NULL,
    "reserve_source_count" integer NOT NULL,
    "card_count" integer NOT NULL,
    "status" "text" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."mvp_release_status" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."export_acl_rts_mvp_package_v01" AS
 SELECT "p"."release_id",
    "rs"."release_name",
    "rs"."status" AS "release_status",
    "rs"."notes" AS "release_notes",
    "p"."section_order",
    "p"."section_id",
    "p"."concept_zone",
    "p"."section_title",
    "p"."section_frame",
    "p"."student_question",
    "p"."boundary_note",
    "p"."card_order",
    "p"."evidence_id",
    "p"."title",
    "p"."finding",
    "p"."evidence_boundary",
    "p"."framework_application",
    "p"."curiosity_question",
    "p"."source_title",
    "p"."citation",
    "p"."doi",
    "p"."journal",
    "p"."year",
    "p"."source_type",
    "p"."locked_source_role",
    "p"."source_safety_note",
    "p"."read_original_source_prompt"
   FROM ("prism_core"."app_acl_rts_mvp_ui_payload_v01" "p"
     LEFT JOIN "prism_core"."mvp_release_status" "rs" ON (("rs"."release_id" = "p"."release_id")))
  ORDER BY "p"."section_order", "p"."card_order";


ALTER VIEW "prism_core"."export_acl_rts_mvp_package_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."export_acl_rts_mvp_full_payload_v01" AS
 SELECT "x"."release_id",
    "x"."release_name",
    "x"."release_status",
    "x"."release_notes",
    "x"."section_order",
    "x"."section_id",
    "x"."concept_zone",
    "x"."section_title",
    "x"."section_frame",
    "x"."student_question",
    "x"."boundary_note",
    "x"."card_order",
    "x"."evidence_id",
    "x"."title",
    "x"."finding",
    "x"."evidence_boundary",
    "x"."framework_application",
    "x"."curiosity_question",
    "x"."source_title",
    "x"."citation",
    "x"."doi",
    "x"."journal",
    "x"."year",
    "x"."source_type",
    "x"."locked_source_role",
    "x"."source_safety_note",
    "x"."read_original_source_prompt",
    "c"."eyebrow",
    "c"."headline",
    "c"."subheadline",
    "c"."primary_boundary",
    "c"."card_label_finding",
    "c"."card_label_boundary",
    "c"."card_label_framework",
    "c"."card_label_curiosity",
    "c"."source_label"
   FROM ("prism_core"."export_acl_rts_mvp_package_v01" "x"
     LEFT JOIN "prism_core"."app_acl_rts_mvp_copy_v01" "c" ON (("c"."release_id" = "x"."release_id")))
  ORDER BY "x"."section_order", "x"."card_order";


ALTER VIEW "prism_core"."export_acl_rts_mvp_full_payload_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."export_acl_rts_mvp_student_payload_v01" AS
 SELECT "display_order",
    "release_id",
    "evidence_id",
    "concept_zone",
    "title",
    "learner_hook",
    "plain_language_takeaway",
    "finding",
    "evidence_boundary",
    "framework_application",
    "misconception_to_avoid",
    "curiosity_question",
    "student_confidence_prompt",
    "source_title",
    "citation",
    "doi",
    "journal",
    "year",
    "source_type",
    "locked_source_role",
    "source_safety_note",
    "read_original_source_prompt",
    "created_at"
   FROM "prism_core"."app_acl_rts_mvp_cards_v01"
  ORDER BY "display_order";


ALTER VIEW "prism_core"."export_acl_rts_mvp_student_payload_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."final_acl_rts_mvp_package_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    'ACL RTS MVP v0.1'::"text" AS "release_name",
    'foundation_locked_for_prototype'::"text" AS "release_status",
    'Five-source ACL RTS evidence framework with 12 student-facing cards, source stack, bridges, tags, and learning paths.'::"text" AS "package_summary",
    'Educational framework only. Not clinical guidance, not a protocol, not return-to-sport clearance.'::"text" AS "boundary_note",
    ( SELECT "jsonb_agg"("to_jsonb"("c".*) ORDER BY "c"."ui_order") AS "jsonb_agg"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01" "c") AS "cards",
    ( SELECT "jsonb_agg"("to_jsonb"("s".*) ORDER BY "s"."source_order") AS "jsonb_agg"
           FROM "prism_core"."app_acl_rts_source_api_v01" "s") AS "sources",
    ( SELECT "jsonb_agg"("to_jsonb"("b".*) ORDER BY "b"."bridge_order") AS "jsonb_agg"
           FROM "prism_core"."app_acl_rts_bridge_public_v01" "b") AS "bridges",
    ( SELECT "jsonb_agg"("to_jsonb"("n".*) ORDER BY "n"."from_ui_order", "n"."recommendation_rank") AS "jsonb_agg"
           FROM "prism_core"."app_acl_rts_next_best_cards_v01" "n") AS "next_best_cards",
    ( SELECT "jsonb_agg"("to_jsonb"("p".*) ORDER BY "p"."path_order", "p"."path_step") AS "jsonb_agg"
           FROM "prism_core"."app_acl_rts_learning_path_api_v01" "p") AS "learning_paths",
    ( SELECT "jsonb_agg"("to_jsonb"("t".*) ORDER BY "t"."total_tag_strength" DESC, "t"."tag_label") AS "jsonb_agg"
           FROM "prism_core"."app_acl_rts_concept_constellation_api_v01" "t") AS "concept_constellations",
    "now"() AS "packaged_at";


ALTER VIEW "prism_core"."final_acl_rts_mvp_package_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."mvp_card_review_status_v01" (
    "evidence_id" "text" NOT NULL,
    "release_id" "text" DEFAULT 'acl_rts_mvp_v0_1'::"text" NOT NULL,
    "content_status" "text" DEFAULT 'draft_needs_human_review'::"text" NOT NULL,
    "source_status" "text" DEFAULT 'source_linked'::"text" NOT NULL,
    "boundary_status" "text" DEFAULT 'boundary_present'::"text" NOT NULL,
    "clinical_safety_status" "text" DEFAULT 'passed_initial_scan'::"text" NOT NULL,
    "replacement_risk_status" "text" DEFAULT 'passed_initial_scan'::"text" NOT NULL,
    "reviewer_note" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."mvp_card_review_status_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."mvp_database_readme_v01" (
    "object_name" "text" NOT NULL,
    "object_type" "text" NOT NULL,
    "purpose" "text" NOT NULL,
    "app_should_read" boolean DEFAULT false NOT NULL,
    "edit_directly" boolean DEFAULT false NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."mvp_database_readme_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."mvp_map_nodes" AS
 SELECT "z"."concept_zone_id",
    "z"."display_name",
    "z"."boundary_rule",
    "z"."student_psychology_frame",
    "count"("c"."evidence_id") AS "evidence_count",
    "count"(*) FILTER (WHERE ("c"."audit_score" >= 100)) AS "high_refinement_count",
    "count"(*) FILTER (WHERE ("c"."approved_for_mvp" = true)) AS "approved_count"
   FROM ("prism_core"."concept_zones" "z"
     LEFT JOIN "prism_core"."evidence_cards" "c" ON (("c"."concept_zone_id" = "z"."concept_zone_id")))
  GROUP BY "z"."concept_zone_id", "z"."display_name", "z"."boundary_rule", "z"."student_psychology_frame", "z"."sort_order"
  ORDER BY "z"."sort_order";


ALTER VIEW "prism_core"."mvp_map_nodes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."mvp_migration_log_v01" (
    "migration_id" "text" NOT NULL,
    "migration_name" "text" NOT NULL,
    "migration_type" "text" NOT NULL,
    "object_created_or_changed" "text" NOT NULL,
    "reason" "text" NOT NULL,
    "risk_level" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."mvp_migration_log_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."mvp_release_changelog_v01" (
    "changelog_id" bigint NOT NULL,
    "release_id" "text" NOT NULL,
    "change_type" "text" NOT NULL,
    "change_summary" "text" NOT NULL,
    "changed_object" "text",
    "boundary_impact" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."mvp_release_changelog_v01" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "prism_core"."mvp_release_changelog_v01_changelog_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "prism_core"."mvp_release_changelog_v01_changelog_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "prism_core"."mvp_release_changelog_v01_changelog_id_seq" OWNED BY "prism_core"."mvp_release_changelog_v01"."changelog_id";



CREATE OR REPLACE VIEW "prism_core"."mvp_source_coverage_audit" AS
 SELECT "sr"."source_id",
    "sr"."title",
    "sr"."locked_source_role",
    "sr"."prism_role_rationale",
    "sr"."include_status",
    "count"("pc"."evidence_id") AS "public_card_count",
        CASE
            WHEN ("count"("pc"."evidence_id") = 0) THEN 'missing_from_public_mvp'::"text"
            WHEN ("count"("pc"."evidence_id") = 1) THEN 'represented_once'::"text"
            ELSE 'represented_multiple_times'::"text"
        END AS "mvp_coverage_status"
   FROM ("prism_core"."source_registry_locked" "sr"
     LEFT JOIN "prism_core"."mvp_public_cards_12" "pc" ON (("pc"."source_id" = "sr"."source_id")))
  GROUP BY "sr"."source_id", "sr"."title", "sr"."locked_source_role", "sr"."prism_role_rationale", "sr"."include_status"
  ORDER BY
        CASE
            WHEN ("count"("pc"."evidence_id") = 0) THEN 1
            WHEN ("count"("pc"."evidence_id") = 1) THEN 2
            ELSE 3
        END, "sr"."source_id";


ALTER VIEW "prism_core"."mvp_source_coverage_audit" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."mvp_source_scope_v01" (
    "source_id" "text",
    "title" "text",
    "locked_source_role" "text",
    "prism_role_rationale" "text",
    "mvp_scope_status" "text",
    "scope_note" "text",
    "scoped_at" timestamp with time zone
);


ALTER TABLE "prism_core"."mvp_source_scope_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."prototype_advanced_health_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01") AS "advanced_card_rows",
    ( SELECT "count"(DISTINCT "app_acl_rts_advanced_map_payload_v01"."ui_order") AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01") AS "unique_card_orders",
    ( SELECT "count"(DISTINCT "app_acl_rts_advanced_map_payload_v01"."concept_zone") AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01") AS "concept_zone_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01"
          WHERE ("app_acl_rts_advanced_map_payload_v01"."card_size" = 'feature'::"text")) AS "feature_card_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_concept_constellation_api_v01") AS "constellation_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_card_energy_profile_v01") AS "energy_profile_rows",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_next_best_cards_v01") AS "next_best_rows",
    ( SELECT "count"(DISTINCT "app_acl_rts_next_best_cards_v01"."from_ui_order") AS "count"
           FROM "prism_core"."app_acl_rts_next_best_cards_v01") AS "cards_with_next_best",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_learning_path_api_v01") AS "learning_path_steps",
    ( SELECT "count"(DISTINCT "app_acl_rts_learning_path_api_v01"."path_id") AS "count"
           FROM "prism_core"."app_acl_rts_learning_path_api_v01") AS "learning_path_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_bridge_public_v01") AS "bridge_rows",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_rows",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01"
          WHERE (("app_acl_rts_advanced_map_payload_v01"."title" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."learner_hook" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."finding" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."misconception_to_avoid" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."curiosity_question" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."student_confidence_prompt" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."energy_role" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."source_title" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."citation" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."doi" IS NULL))) AS "missing_advanced_required_fields",
    "now"() AS "checked_at";


ALTER VIEW "prism_core"."prototype_advanced_health_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."prototype_advanced_language_safety_v01" AS
 SELECT "ui_order",
    "title",
    "concept_zone",
        CASE
            WHEN (("finding" ~~* '%patient should%'::"text") OR ("finding" ~~* '%clinician should%'::"text") OR ("finding" ~~* '%progress when%'::"text") OR ("finding" ~~* '%protocol%'::"text") OR ("finding" ~~* '%clear for%'::"text") OR ("evidence_boundary" ~~* '%patient should%'::"text") OR ("evidence_boundary" ~~* '%clinician should%'::"text") OR ("evidence_boundary" ~~* '%progress when%'::"text") OR ("evidence_boundary" ~~* '%protocol%'::"text") OR ("evidence_boundary" ~~* '%clear for%'::"text") OR ("framework_application" ~~* '%patient should%'::"text") OR ("framework_application" ~~* '%clinician should%'::"text") OR ("framework_application" ~~* '%progress when%'::"text") OR ("framework_application" ~~* '%protocol%'::"text") OR ("framework_application" ~~* '%clear for%'::"text") OR ("plain_language_takeaway" ~~* '%patient should%'::"text") OR ("plain_language_takeaway" ~~* '%clinician should%'::"text") OR ("plain_language_takeaway" ~~* '%progress when%'::"text") OR ("plain_language_takeaway" ~~* '%protocol%'::"text") OR ("plain_language_takeaway" ~~* '%clear for%'::"text") OR ("misconception_to_avoid" ~~* '%patient should%'::"text") OR ("misconception_to_avoid" ~~* '%clinician should%'::"text") OR ("misconception_to_avoid" ~~* '%progress when%'::"text") OR ("misconception_to_avoid" ~~* '%protocol%'::"text") OR ("misconception_to_avoid" ~~* '%clear for%'::"text")) THEN true
            ELSE false
        END AS "language_risk_detected"
   FROM "prism_core"."app_acl_rts_advanced_map_payload_v01";


ALTER VIEW "prism_core"."prototype_advanced_language_safety_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."prototype_api_contract_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    'ACL RTS MVP v0.1'::"text" AS "release_name",
    'prism_core.app_acl_rts_advanced_map_payload_v01'::"text" AS "primary_card_flow_view",
    'prism_core.app_acl_rts_source_api_v01'::"text" AS "source_stack_table",
    'prism_core.app_acl_rts_bridge_public_v01'::"text" AS "concept_bridge_view",
    'prism_core.app_acl_rts_next_best_cards_v01'::"text" AS "related_cards_view",
    'prism_core.app_acl_rts_learning_path_api_v01'::"text" AS "learning_path_view",
    'prism_core.app_acl_rts_concept_constellation_api_v01'::"text" AS "concept_constellation_view",
    'prism_core.final_acl_rts_mvp_package_v01'::"text" AS "full_export_package_view",
    'prism_core.prototype_advanced_health_v01'::"text" AS "health_check_view",
    'External prototype tools may read only prism_core API surfaces listed here. Do not connect to raw extraction, editor, audit, backup, reserve-source, or public source tables.'::"text" AS "connection_rule",
    'Educational framework only. Not clinical guidance, not a protocol, not return-to-sport clearance.'::"text" AS "boundary_note",
    "now"() AS "generated_at";


ALTER VIEW "prism_core"."prototype_api_contract_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."prototype_api_health_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_composed_ui_v01") AS "card_rows",
    ( SELECT "count"(DISTINCT "app_acl_rts_composed_ui_v01"."ui_order") AS "count"
           FROM "prism_core"."app_acl_rts_composed_ui_v01") AS "unique_card_orders",
    ( SELECT "count"(DISTINCT "app_acl_rts_composed_ui_v01"."concept_zone") AS "count"
           FROM "prism_core"."app_acl_rts_composed_ui_v01") AS "concept_zone_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_composed_ui_v01"
          WHERE ("app_acl_rts_composed_ui_v01"."card_size" = 'feature'::"text")) AS "feature_card_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_rows",
    ( SELECT COALESCE("sum"("app_acl_rts_source_api_v01"."card_count"), (0)::numeric) AS "coalesce"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_card_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_bridge_public_v01") AS "bridge_rows",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_composed_ui_v01"
          WHERE (("app_acl_rts_composed_ui_v01"."title" IS NULL) OR ("app_acl_rts_composed_ui_v01"."learner_hook" IS NULL) OR ("app_acl_rts_composed_ui_v01"."plain_language_takeaway" IS NULL) OR ("app_acl_rts_composed_ui_v01"."finding" IS NULL) OR ("app_acl_rts_composed_ui_v01"."evidence_boundary" IS NULL) OR ("app_acl_rts_composed_ui_v01"."framework_application" IS NULL) OR ("app_acl_rts_composed_ui_v01"."misconception_to_avoid" IS NULL) OR ("app_acl_rts_composed_ui_v01"."curiosity_question" IS NULL) OR ("app_acl_rts_composed_ui_v01"."student_confidence_prompt" IS NULL) OR ("app_acl_rts_composed_ui_v01"."source_title" IS NULL) OR ("app_acl_rts_composed_ui_v01"."citation" IS NULL) OR ("app_acl_rts_composed_ui_v01"."doi" IS NULL))) AS "missing_card_required_fields",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_api_v01"
          WHERE (("app_acl_rts_source_api_v01"."source_title" IS NULL) OR ("app_acl_rts_source_api_v01"."citation" IS NULL) OR ("app_acl_rts_source_api_v01"."doi" IS NULL) OR ("app_acl_rts_source_api_v01"."journal" IS NULL) OR ("app_acl_rts_source_api_v01"."year" IS NULL) OR ("app_acl_rts_source_api_v01"."source_type" IS NULL) OR ("app_acl_rts_source_api_v01"."locked_source_role" IS NULL) OR ("app_acl_rts_source_api_v01"."source_note" IS NULL))) AS "missing_source_required_fields",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_bridge_public_v01"
          WHERE (("app_acl_rts_bridge_public_v01"."bridge_label" IS NULL) OR ("app_acl_rts_bridge_public_v01"."student_bridge_explanation" IS NULL) OR ("app_acl_rts_bridge_public_v01"."boundary_note" IS NULL) OR ("app_acl_rts_bridge_public_v01"."from_card_title" IS NULL) OR ("app_acl_rts_bridge_public_v01"."to_card_title" IS NULL))) AS "missing_bridge_required_fields",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_composed_ui_v01"
          WHERE (("app_acl_rts_composed_ui_v01"."finding" ~~* '%patient should%'::"text") OR ("app_acl_rts_composed_ui_v01"."finding" ~~* '%clinician should%'::"text") OR ("app_acl_rts_composed_ui_v01"."finding" ~~* '%progress when%'::"text") OR ("app_acl_rts_composed_ui_v01"."finding" ~~* '%protocol%'::"text") OR ("app_acl_rts_composed_ui_v01"."finding" ~~* '%clear for%'::"text") OR ("app_acl_rts_composed_ui_v01"."evidence_boundary" ~~* '%patient should%'::"text") OR ("app_acl_rts_composed_ui_v01"."evidence_boundary" ~~* '%clinician should%'::"text") OR ("app_acl_rts_composed_ui_v01"."evidence_boundary" ~~* '%progress when%'::"text") OR ("app_acl_rts_composed_ui_v01"."evidence_boundary" ~~* '%protocol%'::"text") OR ("app_acl_rts_composed_ui_v01"."evidence_boundary" ~~* '%clear for%'::"text") OR ("app_acl_rts_composed_ui_v01"."framework_application" ~~* '%patient should%'::"text") OR ("app_acl_rts_composed_ui_v01"."framework_application" ~~* '%clinician should%'::"text") OR ("app_acl_rts_composed_ui_v01"."framework_application" ~~* '%progress when%'::"text") OR ("app_acl_rts_composed_ui_v01"."framework_application" ~~* '%protocol%'::"text") OR ("app_acl_rts_composed_ui_v01"."framework_application" ~~* '%clear for%'::"text") OR ("app_acl_rts_composed_ui_v01"."plain_language_takeaway" ~~* '%patient should%'::"text") OR ("app_acl_rts_composed_ui_v01"."plain_language_takeaway" ~~* '%clinician should%'::"text") OR ("app_acl_rts_composed_ui_v01"."plain_language_takeaway" ~~* '%progress when%'::"text") OR ("app_acl_rts_composed_ui_v01"."plain_language_takeaway" ~~* '%protocol%'::"text") OR ("app_acl_rts_composed_ui_v01"."plain_language_takeaway" ~~* '%clear for%'::"text"))) AS "clinical_language_risk_count",
    "now"() AS "checked_at";


ALTER VIEW "prism_core"."prototype_api_health_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."prototype_connection_contract_v01" (
    "contract_id" "text" NOT NULL,
    "release_id" "text" NOT NULL,
    "allowed_card_table" "text" NOT NULL,
    "allowed_source_table" "text" NOT NULL,
    "blocked_schemas" "text"[] NOT NULL,
    "blocked_tables" "text"[] NOT NULL,
    "connection_rule" "text" NOT NULL,
    "boundary_note" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "prism_core"."prototype_connection_contract_v01" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."prototype_final_health_v01" AS
 SELECT 'acl_rts_mvp_v0_1'::"text" AS "release_id",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01") AS "card_rows",
    ( SELECT "count"(DISTINCT "app_acl_rts_advanced_map_payload_v01"."ui_order") AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01") AS "unique_card_orders",
    ( SELECT "count"(DISTINCT "app_acl_rts_advanced_map_payload_v01"."concept_zone") AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01") AS "concept_zone_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_rows",
    ( SELECT COALESCE("sum"("app_acl_rts_source_api_v01"."card_count"), (0)::numeric) AS "coalesce"
           FROM "prism_core"."app_acl_rts_source_api_v01") AS "source_card_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_bridge_public_v01") AS "bridge_rows",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_next_best_cards_v01") AS "next_best_rows",
    ( SELECT "count"(DISTINCT "app_acl_rts_next_best_cards_v01"."from_ui_order") AS "count"
           FROM "prism_core"."app_acl_rts_next_best_cards_v01") AS "cards_with_next_best",
    ( SELECT "count"(DISTINCT "app_acl_rts_learning_path_api_v01"."path_id") AS "count"
           FROM "prism_core"."app_acl_rts_learning_path_api_v01") AS "learning_path_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_learning_path_api_v01") AS "learning_path_steps",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_concept_constellation_api_v01") AS "constellation_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_card_energy_profile_v01") AS "energy_profile_rows",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01"
          WHERE (("app_acl_rts_advanced_map_payload_v01"."title" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."learner_hook" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."finding" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."misconception_to_avoid" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."curiosity_question" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."student_confidence_prompt" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."source_title" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."citation" IS NULL) OR ("app_acl_rts_advanced_map_payload_v01"."doi" IS NULL))) AS "missing_required_field_count",
    ( SELECT "count"(*) AS "count"
           FROM "prism_core"."app_acl_rts_advanced_map_payload_v01"
          WHERE (("app_acl_rts_advanced_map_payload_v01"."finding" ~~* '%patient should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."finding" ~~* '%clinician should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."finding" ~~* '%progress when%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."finding" ~~* '%protocol%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."finding" ~~* '%clear for%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" ~~* '%patient should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" ~~* '%clinician should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" ~~* '%progress when%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" ~~* '%protocol%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."evidence_boundary" ~~* '%clear for%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" ~~* '%patient should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" ~~* '%clinician should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" ~~* '%progress when%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" ~~* '%protocol%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."framework_application" ~~* '%clear for%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" ~~* '%patient should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" ~~* '%clinician should%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" ~~* '%progress when%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" ~~* '%protocol%'::"text") OR ("app_acl_rts_advanced_map_payload_v01"."plain_language_takeaway" ~~* '%clear for%'::"text"))) AS "clinical_language_risk_count",
    "now"() AS "checked_at";


ALTER VIEW "prism_core"."prototype_final_health_v01" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."release_acl_rts_mvp_v0_1_snapshot" (
    "ui_order" bigint NOT NULL,
    "release_id" "text",
    "concept_zone" "text",
    "section_intro" "text",
    "section_subtitle" "text",
    "section_guiding_question" "text",
    "card_size" "text",
    "card_role" "text",
    "visual_weight" integer,
    "reveal_style" "text",
    "energy_role" "text",
    "total_concept_strength" bigint,
    "bridge_connection_count" bigint,
    "next_best_count" bigint,
    "student_energy_explanation" "text",
    "title" "text",
    "learner_hook" "text",
    "plain_language_takeaway" "text",
    "finding" "text",
    "evidence_boundary" "text",
    "framework_application" "text",
    "misconception_to_avoid" "text",
    "curiosity_question" "text",
    "student_confidence_prompt" "text",
    "concept_tags" "text"[],
    "concept_meanings" "text"[],
    "source_title" "text",
    "citation" "text",
    "doi" "text",
    "source_safety_note" "text",
    "read_original_source_prompt" "text"
);


ALTER TABLE "prism_core"."release_acl_rts_mvp_v0_1_snapshot" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_core"."sources" (
    "source_id" "text" NOT NULL,
    "title" "text",
    "citation" "text",
    "doi" "text",
    "journal" "text",
    "publication_year" integer,
    "source_type" "text",
    "methodology_note" "text",
    "population_scope" "text",
    "access_rights_status" "text",
    "provenance_status" "text",
    "source_review_status" "text",
    "prism_source_role" "text",
    "mvp_use_decision" "text",
    "mvp_reason" "text",
    "source_quality_note" "text",
    "raw_source" "jsonb"
);


ALTER TABLE "prism_core"."sources" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_core"."source_stack" AS
 SELECT "s"."source_id",
    "s"."title",
    "s"."citation",
    "s"."doi",
    "s"."publication_year",
    "s"."source_type",
    "s"."methodology_note",
    "s"."population_scope",
    "s"."prism_source_role",
    "s"."mvp_use_decision",
    "s"."mvp_reason",
    "count"("c"."evidence_id") AS "evidence_card_count",
    ("avg"("c"."audit_score"))::numeric(10,2) AS "average_audit_score",
    "max"("c"."audit_score") AS "max_audit_score"
   FROM ("prism_core"."sources" "s"
     LEFT JOIN "prism_core"."evidence_cards" "c" ON (("c"."source_id" = "s"."source_id")))
  GROUP BY "s"."source_id", "s"."title", "s"."citation", "s"."doi", "s"."publication_year", "s"."source_type", "s"."methodology_note", "s"."population_scope", "s"."prism_source_role", "s"."mvp_use_decision", "s"."mvp_reason"
  ORDER BY
        CASE "s"."prism_source_role"
            WHEN 'Anchor Source'::"text" THEN 1
            WHEN 'Primary Evidence Node'::"text" THEN 2
            WHEN 'Context Source'::"text" THEN 3
            WHEN 'Historical Context Source'::"text" THEN 4
            ELSE 5
        END, "s"."publication_year" DESC NULLS LAST;


ALTER VIEW "prism_core"."source_stack" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_editor"."deep_refinement_queue" AS
 SELECT "evidence_id",
    "source_id",
    "source_title",
    "concept_zone_display",
    "object_role",
    "audit_score",
    "blocked_language_flag",
    "replacement_risk_flag",
    "missing_field_flag",
    "long_card_flag",
    "title",
    "finding",
    "evidence_boundary",
    "framework_application",
    "curiosity_question",
    "source_supports",
    "source_does_not_establish",
    "do_not_use_as",
    "source_anchor",
    "risk_category",
        CASE
            WHEN "blocked_language_flag" THEN 'clinical_drift_scan_first'::"text"
            WHEN "replacement_risk_flag" THEN 'source_replacement_scan_first'::"text"
            WHEN "missing_field_flag" THEN 'missing_prism_field'::"text"
            WHEN "long_card_flag" THEN 'compress_for_student_clarity'::"text"
            ELSE 'prism_language_refinement'::"text"
        END AS "next_action"
   FROM "prism_core"."evidence_cards" "c"
  ORDER BY "audit_score" DESC, "evidence_id";


ALTER VIEW "prism_editor"."deep_refinement_queue" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_editor"."mvp_12_rewrite_quality_check" AS
 SELECT "evidence_id",
        CASE
            WHEN (("revised_title" ~* '(treat|prescribe|protocol|clear|clearance|progress when|return at|patient should|clinician should|use this intervention|best treatment)'::"text") OR ("revised_finding" ~* '(treat|prescribe|protocol|clear|clearance|progress when|return at|patient should|clinician should|use this intervention|best treatment)'::"text") OR ("revised_evidence_boundary" ~* '(treat|prescribe|protocol|clear|clearance|progress when|return at|patient should|clinician should|use this intervention|best treatment)'::"text") OR ("revised_framework_application" ~* '(treat|prescribe|protocol|clear|clearance|progress when|return at|patient should|clinician should|use this intervention|best treatment)'::"text") OR ("revised_curiosity_question" ~* '(treat|prescribe|protocol|clear|clearance|progress when|return at|patient should|clinician should|use this intervention|best treatment)'::"text")) THEN true
            ELSE false
        END AS "blocked_language_detected",
        CASE
            WHEN (("length"("revised_finding") > 260) OR ("length"("revised_evidence_boundary") > 300) OR ("length"("revised_framework_application") > 300) OR ("length"("revised_curiosity_question") > 220)) THEN true
            ELSE false
        END AS "length_review_needed",
        CASE
            WHEN (("revised_finding" IS NULL) OR ("revised_evidence_boundary" IS NULL) OR ("revised_framework_application" IS NULL) OR ("revised_curiosity_question" IS NULL) OR (TRIM(BOTH FROM "revised_finding") = ''::"text") OR (TRIM(BOTH FROM "revised_evidence_boundary") = ''::"text") OR (TRIM(BOTH FROM "revised_framework_application") = ''::"text") OR (TRIM(BOTH FROM "revised_curiosity_question") = ''::"text")) THEN true
            ELSE false
        END AS "missing_spine_field",
    "rewrite_status"
   FROM "prism_editor"."mvp_card_rewrites_12" "r"
  ORDER BY "evidence_id";


ALTER VIEW "prism_editor"."mvp_12_rewrite_quality_check" OWNER TO "postgres";


CREATE OR REPLACE VIEW "prism_editor"."mvp_12_rewrite_review" AS
 SELECT "c"."evidence_id",
    "c"."source_id",
    "c"."locked_source_role",
    "c"."concept_zone_display",
    "c"."title" AS "current_title",
    "r"."revised_title",
    "c"."finding" AS "current_finding",
    "r"."revised_finding",
    "c"."evidence_boundary" AS "current_evidence_boundary",
    "r"."revised_evidence_boundary",
    "c"."framework_application" AS "current_framework_application",
    "r"."revised_framework_application",
    "c"."curiosity_question" AS "current_curiosity_question",
    "r"."revised_curiosity_question",
    "c"."blocked_language_flag",
    "c"."replacement_risk_flag",
    "c"."audit_score",
    "r"."rewrite_status"
   FROM ("prism_editor"."mvp_candidate_cards_12" "c"
     JOIN "prism_editor"."mvp_card_rewrites_12" "r" ON (("r"."evidence_id" = "c"."evidence_id")))
  ORDER BY "c"."source_id", "c"."evidence_id";


ALTER VIEW "prism_editor"."mvp_12_rewrite_review" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "prism_editor"."refinement_drafts" (
    "evidence_id" "text" NOT NULL,
    "draft_title" "text",
    "draft_finding" "text",
    "draft_boundary" "text",
    "draft_framework_application" "text",
    "draft_curiosity_question" "text",
    "reviewer_status" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "prism_editor"."refinement_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boundary_notes" (
    "boundary_id" "text" NOT NULL,
    "source_id" "text",
    "evidence_reference" "text",
    "boundary_type" "text",
    "boundary_text" "text",
    "evidence_id" "text",
    "boundary_review_status" "text" DEFAULT 'needs_review'::"text",
    "boundary_role" "text",
    "public_boundary_text" "text",
    "reviewer_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."boundary_notes" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."boundary_filter" AS
 SELECT "bn"."boundary_id",
    "bn"."source_id",
    "s"."title" AS "source_title",
    COALESCE(NULLIF(TRIM(BOTH FROM "bn"."evidence_reference"), ''::"text"), 'source_level'::"text") AS "evidence_reference",
    "bn"."boundary_type",
    "bn"."boundary_text"
   FROM ("public"."boundary_notes" "bn"
     LEFT JOIN "public"."sources" "s" ON (("bn"."source_id" = "s"."source_id")));


ALTER VIEW "public"."boundary_filter" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."concept_zones" (
    "concept_zone" "text" NOT NULL,
    "display_order" integer NOT NULL,
    "zone_boundary" "text",
    "is_active" boolean DEFAULT true,
    "concept_zone_id" "text",
    "concept_zone_name" "text",
    "zone_scope" "text",
    "included_examples" "text",
    "boundary_note" "text",
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."concept_zones" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."construct_explorer" WITH ("security_invoker"='true') AS
 WITH "curated_constructs" AS (
         SELECT "t"."construct_id",
            "t"."construct_name",
            "t"."construct_family",
            "t"."definition_or_scope",
            "t"."dependency_tier",
            "t"."keywords"
           FROM ( VALUES ('rts_outcome'::"text",'RTS Outcome'::"text",'Outcome Language'::"text",'Return to participation, return to sport, and return to performance as distinct outcome levels.'::"text",'1'::"text",ARRAY['return to sport'::"text", 'return to performance'::"text", 'return to participation'::"text", 'preinjury sport'::"text"]), ('second_acl_injury'::"text",'Second ACL Injury'::"text",'Injury Outcome'::"text",'Ipsilateral graft rupture and contralateral ACL injury outcomes.'::"text",'1'::"text",ARRAY['second acl'::"text", 'reinjury'::"text", 'graft rupture'::"text", 'contralateral'::"text"]), ('timing_9_months'::"text",'Timing and 9 Months'::"text",'Timing'::"text",'Time from ACL reconstruction to return to sport, including the 9-month timing evidence layer.'::"text",'2'::"text",ARRAY['9 months'::"text", 'timing'::"text", 'time to return'::"text", 'before 9 months'::"text"]), ('criteria_testing'::"text",'Criteria and Testing'::"text",'Criteria / Testing'::"text",'Hop tests, strength tests, test batteries, and pass/fail criterion status.'::"text",'3'::"text",ARRAY['criteria'::"text", 'criterion'::"text", 'test battery'::"text", 'hop'::"text", 'strength'::"text", 'pass'::"text"]), ('limb_symmetry_lsi'::"text",'Limb Symmetry Index'::"text",'Capacity'::"text",'LSI as a strength and hop-performance comparison metric with known construct limits.'::"text",'3'::"text",ARRAY['lsi'::"text", 'limb symmetry'::"text", 'symmetry'::"text"]), ('quadriceps_strength'::"text",'Quadriceps Strength'::"text",'Capacity'::"text",'Quadriceps strength, isokinetic testing, and strength reference values.'::"text",'3'::"text",ARRAY['quadriceps'::"text"]), ('hamstring_strength'::"text",'Hamstring Strength'::"text",'Capacity'::"text",'Hamstring strength, hamstring-to-quadriceps ratio, and graft-related strength findings.'::"text",'3'::"text",ARRAY['hamstring'::"text", 'hamstring-to-quadriceps'::"text", 'h:q'::"text"]), ('side_hop'::"text",'Side Hop'::"text",'Criteria / Testing'::"text",'Side-hop performance as a specific test signal in the RTS evidence base.'::"text",'3'::"text",ARRAY['side hop'::"text"]), ('psychological_readiness'::"text",'Psychological Readiness'::"text",'Readiness'::"text",'ACL-RSI, fear, confidence, psychological readiness, and readiness thresholds.'::"text",'4'::"text",ARRAY['psychological'::"text", 'acl-rsi'::"text", 'fear'::"text", 'confidence'::"text"]), ('psychosocial_context'::"text",'Psychosocial Context'::"text",'Readiness'::"text",'Fear of reinjury, uncertainty, social comparison, sport identity, and therapeutic relationship.'::"text",'4'::"text",ARRAY['psychosocial'::"text", 'fear'::"text", 'uncertainty'::"text", 'social comparison'::"text", 'identity'::"text"]), ('clearance_readiness_gap'::"text",'Clearance vs Readiness Gap'::"text",'Decision Ecology'::"text",'Difference between being cleared and meeting objective or combined readiness criteria.'::"text",'5'::"text",ARRAY['clearance'::"text", 'cleared'::"text", 'readiness'::"text"]), ('decision_ecology'::"text",'Decision Ecology'::"text",'Decision Ecology'::"text",'Who participates in RTS decisions, whether testing occurred, and how rehabilitation ended.'::"text",'5'::"text",ARRAY['decision'::"text", 'physical therapist'::"text", 'testing'::"text", 'rehabilitation cessation'::"text"])) "t"("construct_id", "construct_name", "construct_family", "definition_or_scope", "dependency_tier", "keywords")
        ), "matches" AS (
         SELECT "cc"."construct_id",
            "cc"."construct_name",
            "cc"."construct_family",
            "cc"."definition_or_scope",
            "cc"."dependency_tier",
            "eo"."evidence_id",
            "eo"."source_id"
           FROM ("curated_constructs" "cc"
             LEFT JOIN "public"."evidence_objects" "eo" ON ((EXISTS ( SELECT 1
                   FROM "unnest"("cc"."keywords") "keyword"("keyword")
                  WHERE (("eo"."concept_zone" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")) OR ("eo"."source_linked_finding" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")) OR ("eo"."numeric_result" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")) OR ("eo"."evidence_boundary" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")) OR ("eo"."prism_use" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")) OR ("eo"."do_not_use_as" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")) OR ("eo"."curiosity_question" ~~* (('%'::"text" || "keyword"."keyword") || '%'::"text")))))))
        )
 SELECT "construct_id",
    "construct_name",
    "construct_family",
    "definition_or_scope",
    "dependency_tier",
    "count"(DISTINCT "source_id") AS "source_count",
    "string_agg"(DISTINCT "source_id", ', '::"text" ORDER BY "source_id") AS "linked_sources",
    "count"(DISTINCT "evidence_id") AS "evidence_object_count"
   FROM "matches"
  GROUP BY "construct_id", "construct_name", "construct_family", "definition_or_scope", "dependency_tier";


ALTER VIEW "public"."construct_explorer" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."constructs" (
    "construct_id" "text" NOT NULL,
    "construct_name" "text",
    "construct_family" "text",
    "definition_or_scope" "text",
    "synonyms" "text",
    "dependency_tier" "text"
);


ALTER TABLE "public"."constructs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."curiosity_prompts" (
    "prompt_id" "text" NOT NULL,
    "evidence_id" "text",
    "source_id" "text",
    "question" "text",
    "prompt_category" "text"
);


ALTER TABLE "public"."curiosity_prompts" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."evidence_boundary_browser" AS
 SELECT "eo"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    "eo"."concept_zone",
    "eo"."source_linked_finding",
    "eo"."numeric_result",
    "eo"."evidence_boundary",
    "eo"."prism_use",
    "eo"."do_not_use_as",
    "eo"."certainty_flag",
    "eo"."curiosity_question",
    "bn"."boundary_type",
    "bn"."boundary_text"
   FROM (("public"."evidence_objects" "eo"
     LEFT JOIN "public"."sources" "s" ON (("eo"."source_id" = "s"."source_id")))
     LEFT JOIN "public"."boundary_notes" "bn" ON ((("bn"."source_id" = "eo"."source_id") AND (("lower"("bn"."evidence_reference") ~~ (('%'::"text" || "lower"("eo"."evidence_id")) || '%'::"text")) OR ("lower"("bn"."evidence_reference") ~~ (('%'::"text" || "lower"(('EO-'::"text" || "eo"."evidence_number"))) || '%'::"text")) OR ("lower"("bn"."evidence_reference") = 'source_level'::"text")))));


ALTER VIEW "public"."evidence_boundary_browser" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."evidence_browser" WITH ("security_invoker"='true') AS
 SELECT "eo"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    "eo"."concept_zone",
    "eo"."source_linked_finding",
    "eo"."numeric_result",
    "eo"."evidence_boundary",
    "eo"."prism_use",
    "eo"."do_not_use_as",
    "eo"."certainty_flag",
    "eo"."curiosity_question"
   FROM ("public"."evidence_objects" "eo"
     LEFT JOIN "public"."sources" "s" ON (("eo"."source_id" = "s"."source_id")));


ALTER VIEW "public"."evidence_browser" OWNER TO "postgres";


COMMENT ON VIEW "public"."evidence_browser" IS 'LEGACY BROWSER VIEW. Useful for debugging raw evidence objects, not the final public curation surface.';



CREATE TABLE IF NOT EXISTS "public"."evidence_construct_links" (
    "evidence_id" "text" NOT NULL,
    "construct_id" "text" NOT NULL,
    "link_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."evidence_construct_links" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."evidence_detail_with_boundaries" WITH ("security_invoker"='true') AS
 SELECT "eo"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    "eo"."concept_zone",
    "eo"."source_linked_finding",
    "eo"."numeric_result",
    "eo"."author_interpretation",
    "eo"."evidence_boundary",
    "eo"."prism_use",
    "eo"."do_not_use_as",
    "eo"."certainty_flag",
    "eo"."curiosity_question",
    "bn"."boundary_id",
    COALESCE(NULLIF(TRIM(BOTH FROM "bn"."evidence_reference"), ''::"text"), 'source_level'::"text") AS "evidence_reference",
    "bn"."boundary_type",
    "bn"."boundary_text"
   FROM (("public"."evidence_objects" "eo"
     LEFT JOIN "public"."sources" "s" ON (("eo"."source_id" = "s"."source_id")))
     LEFT JOIN "public"."boundary_notes" "bn" ON (("bn"."source_id" = "eo"."source_id")));


ALTER VIEW "public"."evidence_detail_with_boundaries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guardrails" (
    "guardrail_id" "text" NOT NULL,
    "guardrail_name" "text",
    "rule_text" "text",
    "applies_to" "text"
);


ALTER TABLE "public"."guardrails" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."evidence_with_guardrails" AS
 SELECT "eo"."evidence_id",
    "s"."title" AS "source_title",
    "eo"."concept_zone",
    "eo"."source_linked_finding",
    "eo"."numeric_result",
    "eo"."evidence_boundary",
    "eo"."prism_use",
    "eo"."do_not_use_as",
    "eo"."certainty_flag",
    "string_agg"("g"."rule_text", ' | '::"text") AS "global_guardrails"
   FROM (("public"."evidence_objects" "eo"
     LEFT JOIN "public"."sources" "s" ON (("eo"."source_id" = "s"."source_id")))
     CROSS JOIN "public"."guardrails" "g")
  GROUP BY "eo"."evidence_id", "s"."title", "eo"."concept_zone", "eo"."source_linked_finding", "eo"."numeric_result", "eo"."evidence_boundary", "eo"."prism_use", "eo"."do_not_use_as", "eo"."certainty_flag";


ALTER VIEW "public"."evidence_with_guardrails" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."flow_links" (
    "flow_link_id" "text" NOT NULL,
    "source_id" "text",
    "link_target" "text",
    "relationship_type" "text",
    "description" "text"
);


ALTER TABLE "public"."flow_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mvp_views" (
    "view_id" "text" NOT NULL,
    "view_name" "text",
    "query_pattern" "text",
    "output_fields" "text",
    "purpose" "text"
);


ALTER TABLE "public"."mvp_views" OWNER TO "postgres";


COMMENT ON TABLE "public"."mvp_views" IS 'INTERNAL/LEGACY. Do not use for public PRISM MVP UI unless renamed and reworked into Discovery Trails or Evidence Map Views.';



CREATE OR REPLACE VIEW "public"."prism_curation_qa_dashboard" WITH ("security_invoker"='true') AS
 SELECT "count"(*) AS "total_evidence_objects",
    "count"(*) FILTER (WHERE (("public_title" IS NULL) OR ("public_title" = ''::"text"))) AS "missing_public_title",
    "count"(*) FILTER (WHERE (("public_finding" IS NULL) OR ("public_finding" = ''::"text"))) AS "missing_public_finding",
    "count"(*) FILTER (WHERE (("public_boundary" IS NULL) OR ("public_boundary" = ''::"text"))) AS "missing_public_boundary",
    "count"(*) FILTER (WHERE (("public_framework_application" IS NULL) OR ("public_framework_application" = ''::"text"))) AS "missing_framework_application",
    "count"(*) FILTER (WHERE (("public_open_question" IS NULL) OR ("public_open_question" = ''::"text"))) AS "missing_open_question",
    "count"(*) FILTER (WHERE (("source_supports" IS NULL) OR ("source_supports" = ''::"text"))) AS "missing_source_supports",
    "count"(*) FILTER (WHERE (("source_does_not_establish" IS NULL) OR ("source_does_not_establish" = ''::"text"))) AS "missing_source_does_not_establish",
    "count"(*) FILTER (WHERE ("blocked_language_flag" = true)) AS "blocked_language_count",
    "count"(*) FILTER (WHERE ("replacement_risk_status" <> 'scan_clear'::"text")) AS "replacement_risk_count",
    "count"(*) FILTER (WHERE ("source_traceability_status" <> 'traceable_enough_for_review'::"text")) AS "traceability_issue_count",
    "count"(*) FILTER (WHERE ("boundary_review_status" <> 'boundary_present_needs_human_review'::"text")) AS "boundary_issue_count",
    "count"(*) FILTER (WHERE (("human_review_status" = 'approved'::"text") AND ("approved_for_public" = true) AND ("blocked_language_flag" = false))) AS "public_ready_count"
   FROM "public"."prism_evidence_curation";


ALTER VIEW "public"."prism_curation_qa_dashboard" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."prism_framework_inference_layer" WITH ("security_invoker"='true') AS
 WITH "base" AS (
         SELECT "eb"."evidence_id",
            "eb"."source_id",
            "eb"."source_title",
            "eb"."citation",
            "eb"."doi",
            "eb"."concept_zone",
            "eb"."source_linked_finding",
            "eb"."numeric_result",
            "eb"."evidence_boundary",
            "eb"."prism_use",
            "eb"."do_not_use_as",
            "eb"."curiosity_question",
            "lower"("concat_ws"(' '::"text", "eb"."evidence_id", "eb"."source_id", "eb"."source_title", "eb"."citation", "eb"."concept_zone", "eb"."source_linked_finding", "eb"."numeric_result", "eb"."evidence_boundary", "eb"."prism_use", "eb"."do_not_use_as", "eb"."curiosity_question")) AS "search_blob"
           FROM "public"."evidence_browser" "eb"
        )
 SELECT "evidence_id",
    "source_id",
    "source_title",
    "citation",
    "doi",
    "concept_zone",
    COALESCE(NULLIF(TRIM(BOTH FROM "source_linked_finding"), ''::"text"), 'Needs finding curation'::"text") AS "prism_native_finding",
    NULLIF(TRIM(BOTH FROM "numeric_result"), ''::"text") AS "numeric_result",
    COALESCE(NULLIF(TRIM(BOTH FROM "evidence_boundary"), ''::"text"), 'Source boundary not yet specified'::"text") AS "evidence_boundary",
    COALESCE(NULLIF(TRIM(BOTH FROM "prism_use"), ''::"text"), 'Framework use not yet specified'::"text") AS "framework_application",
    COALESCE(NULLIF(TRIM(BOTH FROM "do_not_use_as"), ''::"text"), 'Do not use as standalone rule'::"text") AS "source_does_not_establish",
    COALESCE(NULLIF(TRIM(BOTH FROM "curiosity_question"), ''::"text"), 'What does this source help clarify?'::"text") AS "open_question",
        CASE
            WHEN ((POSITION(('not clearance'::"text") IN ("search_blob")) > 0) OR (POSITION(('not a clearance'::"text") IN ("search_blob")) > 0) OR (POSITION(('does not establish'::"text") IN ("search_blob")) > 0) OR (POSITION(('do not use'::"text") IN ("search_blob")) > 0)) THEN 'Evidence Boundary Card'::"text"
            WHEN ((POSITION(('limitation'::"text") IN ("search_blob")) > 0) OR (POSITION(('boundary'::"text") IN ("search_blob")) > 0) OR (POSITION(('uncertainty'::"text") IN ("search_blob")) > 0) OR (POSITION(('does not establish'::"text") IN ("search_blob")) > 0)) THEN 'Framework Break'::"text"
            WHEN (COALESCE("numeric_result", ''::"text") <> ''::"text") THEN 'Primary Evidence Node'::"text"
            WHEN ((POSITION(('question'::"text") IN ("search_blob")) > 0) OR (POSITION(('explore'::"text") IN ("search_blob")) > 0) OR (POSITION(('curiosity'::"text") IN ("search_blob")) > 0)) THEN 'Curiosity Trail'::"text"
            ELSE 'Supporting Node'::"text"
        END AS "evidence_role",
        CASE
            WHEN ((COALESCE("numeric_result", ''::"text") <> ''::"text") AND (COALESCE("evidence_boundary", ''::"text") <> ''::"text")) THEN 'Source-supported signal'::"text"
            WHEN (COALESCE("numeric_result", ''::"text") <> ''::"text") THEN 'Measured signal'::"text"
            WHEN (COALESCE("evidence_boundary", ''::"text") <> ''::"text") THEN 'Bounded signal'::"text"
            ELSE 'Context signal'::"text"
        END AS "confidence_level",
        CASE
            WHEN ((POSITION(('not clearance'::"text") IN ("search_blob")) > 0) OR (POSITION(('not a clearance'::"text") IN ("search_blob")) > 0) OR (POSITION(('return-to-sport clearance'::"text") IN ("search_blob")) > 0)) THEN 'Clearance drift risk'::"text"
            WHEN ((POSITION(('protocol'::"text") IN ("search_blob")) > 0) OR (POSITION(('progression'::"text") IN ("search_blob")) > 0) OR (POSITION(('dosage'::"text") IN ("search_blob")) > 0)) THEN 'Protocol drift risk'::"text"
            WHEN ((POSITION(('population'::"text") IN ("search_blob")) > 0) OR (POSITION(('generalizability'::"text") IN ("search_blob")) > 0) OR (POSITION(('sample'::"text") IN ("search_blob")) > 0)) THEN 'Population boundary'::"text"
            WHEN (COALESCE("evidence_boundary", ''::"text") <> ''::"text") THEN 'Interpretation boundary'::"text"
            ELSE 'Uncertainty not yet labeled'::"text"
        END AS "uncertainty_flag",
        CASE
            WHEN ((POSITION(('not clearance'::"text") IN ("search_blob")) > 0) OR (POSITION(('protocol'::"text") IN ("search_blob")) > 0) OR (POSITION(('patient'::"text") IN ("search_blob")) > 0) OR (POSITION(('dosage'::"text") IN ("search_blob")) > 0)) THEN 'High replacement risk'::"text"
            WHEN (COALESCE("evidence_boundary", ''::"text") <> ''::"text") THEN 'Moderate overgeneralization risk'::"text"
            ELSE 'Low replacement risk'::"text"
        END AS "risk_category",
        CASE
            WHEN (COALESCE("source_linked_finding", ''::"text") <> ''::"text") THEN "source_linked_finding"
            ELSE 'Source support not yet specified'::"text"
        END AS "source_supports",
    'evidence suggests; this source supports; this finding is limited by; this does not establish; this raises the question'::"text" AS "allowed_language",
    'treat this by; prescribe; patient should; clinician should; return to sport at; protocol source; guaranteed'::"text" AS "blocked_language",
        CASE
            WHEN (COALESCE("source_linked_finding", ''::"text") <> ''::"text") THEN "left"("source_linked_finding", 90)
            ELSE 'Evidence object'::"text"
        END AS "user_facing_title"
   FROM "base";


ALTER VIEW "public"."prism_framework_inference_layer" OWNER TO "postgres";


COMMENT ON VIEW "public"."prism_framework_inference_layer" IS 'PRISM INTERNAL INFERENCE VIEW. Used to organize evidence into Prism-safe framework language before public curation.';



CREATE OR REPLACE VIEW "public"."prism_human_curation_queue" WITH ("security_invoker"='true') AS
 SELECT "pec"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    COALESCE("pec"."concept_zone_override", "eo"."concept_zone") AS "concept_zone",
    "pec"."public_title",
    "pec"."public_finding",
    "pec"."public_boundary",
    "pec"."public_framework_application",
    "pec"."public_open_question",
    "pec"."source_supports",
    "pec"."source_does_not_establish",
    "pec"."evidence_role",
    "pec"."confidence_level",
    "pec"."uncertainty_flag",
    "pec"."risk_category",
    "pec"."human_review_status",
    "pec"."curation_status",
    "pec"."approved_for_public",
    "pec"."blocked_language_flag",
    "pec"."replacement_risk_status",
    "pec"."source_traceability_status",
    "pec"."boundary_review_status",
    "pec"."reviewer_note",
        CASE
            WHEN ("pec"."blocked_language_flag" = true) THEN 'Fix blocked clinical language'::"text"
            WHEN ("pec"."source_traceability_status" = ANY (ARRAY['needs_source_anchor'::"text", 'needs_review'::"text"])) THEN 'Add source traceability'::"text"
            WHEN ("pec"."boundary_review_status" = ANY (ARRAY['missing_or_weak_boundary'::"text", 'needs_review'::"text"])) THEN 'Strengthen evidence boundary'::"text"
            WHEN (("pec"."public_title" IS NULL) OR ("pec"."public_title" = ''::"text")) THEN 'Write public title'::"text"
            WHEN (("pec"."public_finding" IS NULL) OR ("pec"."public_finding" = ''::"text")) THEN 'Write public finding'::"text"
            WHEN (("pec"."public_framework_application" IS NULL) OR ("pec"."public_framework_application" = ''::"text")) THEN 'Write framework application'::"text"
            WHEN (("pec"."public_open_question" IS NULL) OR ("pec"."public_open_question" = ''::"text")) THEN 'Write curiosity question'::"text"
            WHEN ("pec"."human_review_status" <> 'approved'::"text") THEN 'Human review needed'::"text"
            ELSE 'Ready for final approval'::"text"
        END AS "next_manual_action"
   FROM (("public"."prism_evidence_curation" "pec"
     LEFT JOIN "public"."evidence_objects" "eo" ON (("eo"."evidence_id" = "pec"."evidence_id")))
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "eo"."source_id")));


ALTER VIEW "public"."prism_human_curation_queue" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."prism_mvp_usage_layer" WITH ("security_invoker"='true') AS
 SELECT "evidence_id",
    "source_id",
    "source_title",
    "citation",
    "doi",
    "concept_zone",
    "source_linked_finding",
    "numeric_result",
    "evidence_boundary",
    "prism_use",
    "do_not_use_as",
    "certainty_flag" AS "old_certainty_flag",
    "curiosity_question",
    COALESCE("certainty_flag", 'Guided Signal'::"text") AS "mvp_readiness",
    COALESCE("concept_zone", 'General evidence signal'::"text") AS "query_family",
        CASE
            WHEN (COALESCE("numeric_result", ''::"text") <> ''::"text") THEN 'Primary evidence card'::"text"
            WHEN (COALESCE("evidence_boundary", ''::"text") <> ''::"text") THEN 'Boundary warning layer'::"text"
            ELSE 'Guided evidence card'::"text"
        END AS "recommended_surface",
        CASE
            WHEN ((COALESCE("source_linked_finding", ''::"text") <> ''::"text") AND (COALESCE("numeric_result", ''::"text") <> ''::"text")) THEN (("source_linked_finding" || ' Result context: '::"text") || "numeric_result")
            WHEN (COALESCE("source_linked_finding", ''::"text") <> ''::"text") THEN "source_linked_finding"
            WHEN (COALESCE("prism_use", ''::"text") <> ''::"text") THEN "prism_use"
            ELSE 'Needs clearer source-linked finding.'::"text"
        END AS "user_safe_summary",
        CASE
            WHEN (COALESCE("do_not_use_as", ''::"text") <> ''::"text") THEN "do_not_use_as"
            WHEN (COALESCE("evidence_boundary", ''::"text") <> ''::"text") THEN 'Show boundary before use.'::"text"
            ELSE 'Do not use as a standalone rule.'::"text"
        END AS "unsafe_interpretation",
        CASE
            WHEN (COALESCE("curiosity_question", ''::"text") <> ''::"text") THEN "curiosity_question"
            ELSE 'What can the user learn from this evidence object?'::"text"
        END AS "generated_curiosity_prompt",
        CASE
            WHEN (COALESCE("numeric_result", ''::"text") <> ''::"text") THEN 90
            WHEN (COALESCE("evidence_boundary", ''::"text") <> ''::"text") THEN 65
            WHEN (COALESCE("prism_use", ''::"text") <> ''::"text") THEN 55
            ELSE 40
        END AS "priority_score"
   FROM "public"."evidence_browser" "eb";


ALTER VIEW "public"."prism_mvp_usage_layer" OWNER TO "postgres";


COMMENT ON VIEW "public"."prism_mvp_usage_layer" IS 'DEPRECATED. Older MVP readiness language. Do not use as the main public-facing layer.';



CREATE OR REPLACE VIEW "public"."prism_public_evidence_objects" WITH ("security_invoker"='true') AS
 SELECT "eo"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    COALESCE("pec"."concept_zone_override", "eo"."concept_zone", 'Needs concept zone'::"text") AS "concept_zone",
    "pec"."public_title",
    "pec"."public_finding",
    "eo"."numeric_result",
    "pec"."public_boundary",
    "pec"."public_framework_application",
    "pec"."public_open_question",
    "pec"."source_supports",
    "pec"."source_does_not_establish",
    "pec"."evidence_role",
    "pec"."confidence_level",
    "pec"."uncertainty_flag",
    "pec"."risk_category",
    "pec"."source_role",
    "pec"."human_review_status",
    "pec"."curation_status",
    "pec"."approved_for_public",
    "pec"."reviewer_note",
    "pec"."blocked_language_flag",
    "pec"."replacement_risk_status",
    "pec"."source_traceability_status",
    "pec"."boundary_review_status",
    (((((
        CASE
            WHEN (("pec"."public_title" IS NULL) OR ("pec"."public_title" = ''::"text")) THEN 1
            ELSE 0
        END +
        CASE
            WHEN (("pec"."public_finding" IS NULL) OR ("pec"."public_finding" = ''::"text")) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_boundary" IS NULL) OR ("pec"."public_boundary" = ''::"text")) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_framework_application" IS NULL) OR ("pec"."public_framework_application" = ''::"text")) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (("pec"."public_open_question" IS NULL) OR ("pec"."public_open_question" = ''::"text")) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN ("pec"."blocked_language_flag" = true) THEN 1
            ELSE 0
        END) AS "qa_blocker_count",
        CASE
            WHEN ("pec"."blocked_language_flag" = true) THEN 'blocked'::"text"
            WHEN (("pec"."public_title" IS NULL) OR ("pec"."public_title" = ''::"text") OR ("pec"."public_finding" IS NULL) OR ("pec"."public_finding" = ''::"text") OR ("pec"."public_boundary" IS NULL) OR ("pec"."public_boundary" = ''::"text") OR ("pec"."public_framework_application" IS NULL) OR ("pec"."public_framework_application" = ''::"text") OR ("pec"."public_open_question" IS NULL) OR ("pec"."public_open_question" = ''::"text")) THEN 'needs_curation'::"text"
            WHEN ("pec"."approved_for_public" = true) THEN 'public_ready'::"text"
            ELSE 'polished_needs_final_source_check'::"text"
        END AS "public_status"
   FROM (("public"."evidence_objects" "eo"
     LEFT JOIN "public"."prism_evidence_curation" "pec" ON (("pec"."evidence_id" = "eo"."evidence_id")))
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "eo"."source_id")));


ALTER VIEW "public"."prism_public_evidence_objects" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."prism_showcase_evidence_cards" WITH ("security_invoker"='true') AS
 SELECT
        CASE "pec"."evidence_id"
            WHEN 'EO-AGU-01'::"text" THEN 1
            WHEN 'EO-AGU-02'::"text" THEN 2
            WHEN 'EO-AGU-03'::"text" THEN 3
            WHEN 'EO-AGU-05'::"text" THEN 4
            WHEN 'EO-AGU-06'::"text" THEN 5
            WHEN 'EO-1'::"text" THEN 6
            WHEN 'EO-2'::"text" THEN 7
            WHEN 'EO-5'::"text" THEN 8
            WHEN 'EO-6'::"text" THEN 9
            WHEN 'EO-DS01'::"text" THEN 10
            WHEN 'EO-DS02'::"text" THEN 11
            WHEN 'EO-DS04'::"text" THEN 12
            WHEN 'EO-K-001'::"text" THEN 13
            WHEN 'EO-K-004'::"text" THEN 14
            WHEN 'EO-K-006'::"text" THEN 15
            WHEN 'EO-LOSCIALE-2019-01'::"text" THEN 16
            WHEN 'EO-LOSCIALE-2019-02'::"text" THEN 17
            WHEN 'EO-LOSCIALE-2019-05'::"text" THEN 18
            WHEN 'EO-LOSCIALE-2019-06'::"text" THEN 19
            WHEN 'EO-MEIERBACHTOL-2018-03'::"text" THEN 20
            WHEN 'EO-MEIERBACHTOL-2018-04'::"text" THEN 21
            WHEN 'EO-myer2006-02'::"text" THEN 22
            WHEN 'EO-myer2006-03'::"text" THEN 23
            WHEN 'EO-myer2006-06'::"text" THEN 24
            WHEN 'EO-P24-02'::"text" THEN 25
            WHEN 'EO-P24-05'::"text" THEN 26
            WHEN 'EO-P24-06'::"text" THEN 27
            WHEN 'EO-TOOLE-01'::"text" THEN 28
            WHEN 'EO-TOOLE-02'::"text" THEN 29
            WHEN 'EO-VM-03'::"text" THEN 30
            ELSE 999
        END AS "display_rank",
    "pec"."evidence_id",
    "eo"."source_id",
    "s"."title" AS "source_title",
    "s"."citation",
    "s"."doi",
    COALESCE("pec"."concept_zone_override", "eo"."concept_zone", 'Evidence Map'::"text") AS "concept_zone",
        CASE "pec"."evidence_id"
            WHEN 'EO-AGU-01'::"text" THEN 'Side-hop looked useful, but only in one narrow lane'::"text"
            WHEN 'EO-AGU-02'::"text" THEN 'The tests did not become reinjury predictors'::"text"
            WHEN 'EO-AGU-03'::"text" THEN 'Symmetry can make weakness look cleaner than it is'::"text"
            WHEN 'EO-AGU-05'::"text" THEN 'Return to sport is not one outcome'::"text"
            WHEN 'EO-AGU-06'::"text" THEN 'A physical-test review can miss the psychological layer'::"text"
            WHEN 'EO-1'::"text" THEN 'Earlier return carried a second-injury signal'::"text"
            WHEN 'EO-2'::"text" THEN 'Passing symmetry criteria did not settle the risk question'::"text"
            WHEN 'EO-5'::"text" THEN 'The model they wanted to run could not be run'::"text"
            WHEN 'EO-6'::"text" THEN 'Second ACL injury is really two stories'::"text"
            WHEN 'EO-DS01'::"text" THEN 'The barrier athletes kept naming was not only physical'::"text"
            WHEN 'EO-DS02'::"text" THEN 'Fear and uncertainty showed up together'::"text"
            WHEN 'EO-DS04'::"text" THEN 'High school athletes are not just smaller adults'::"text"
            WHEN 'EO-K-001'::"text" THEN 'Participation, sport, and performance split apart'::"text"
            WHEN 'EO-K-004'::"text" THEN 'RTS decisions have a social architecture'::"text"
            WHEN 'EO-K-006'::"text" THEN 'Returning does not always mean performing'::"text"
            WHEN 'EO-LOSCIALE-2019-01'::"text" THEN 'Passing criteria did not erase second injury'::"text"
            WHEN 'EO-LOSCIALE-2019-02'::"text" THEN 'The pooled protection signal stayed uncertain'::"text"
            WHEN 'EO-LOSCIALE-2019-05'::"text" THEN 'RTS criteria were not one standardized thing'::"text"
            WHEN 'EO-LOSCIALE-2019-06'::"text" THEN 'Psychological readiness was mostly missing'::"text"
            WHEN 'EO-MEIERBACHTOL-2018-03'::"text" THEN 'Readiness changed when the threshold changed'::"text"
            WHEN 'EO-MEIERBACHTOL-2018-04'::"text" THEN 'Mind and function did not move as one'::"text"
            WHEN 'EO-myer2006-02'::"text" THEN 'Proposed thresholds are not validated thresholds'::"text"
            WHEN 'EO-myer2006-03'::"text" THEN 'A staged algorithm is not the same as proof'::"text"
            WHEN 'EO-myer2006-06'::"text" THEN 'The authors named their own limits'::"text"
            WHEN 'EO-P24-02'::"text" THEN 'Timing mattered, but the certainty was very low'::"text"
            WHEN 'EO-P24-05'::"text" THEN 'The timing story changed across methods'::"text"
            WHEN 'EO-P24-06'::"text" THEN 'Very low certainty is part of the finding'::"text"
            WHEN 'EO-TOOLE-01'::"text" THEN 'Cleared athletes often did not meet all cutoffs'::"text"
            WHEN 'EO-TOOLE-02'::"text" THEN 'Quadriceps strength was the hardest criterion to satisfy'::"text"
            WHEN 'EO-VM-03'::"text" THEN 'The denominator can distort the symmetry story'::"text"
            ELSE "pec"."public_title"
        END AS "showcase_title",
        CASE "pec"."evidence_id"
            WHEN 'EO-AGU-01'::"text" THEN 'Useful signal, narrow lane'::"text"
            WHEN 'EO-AGU-02'::"text" THEN 'Prediction boundary'::"text"
            WHEN 'EO-AGU-03'::"text" THEN 'Measurement trap'::"text"
            WHEN 'EO-AGU-05'::"text" THEN 'Outcome language'::"text"
            WHEN 'EO-AGU-06'::"text" THEN 'Scope blind spot'::"text"
            WHEN 'EO-1'::"text" THEN 'Timing signal'::"text"
            WHEN 'EO-2'::"text" THEN 'Criteria uncertainty'::"text"
            WHEN 'EO-5'::"text" THEN 'Statistical boundary'::"text"
            WHEN 'EO-6'::"text" THEN 'Outcome splitting'::"text"
            WHEN 'EO-DS01'::"text" THEN 'Lived experience'::"text"
            WHEN 'EO-DS02'::"text" THEN 'Fear and uncertainty'::"text"
            WHEN 'EO-DS04'::"text" THEN 'Population context'::"text"
            WHEN 'EO-K-001'::"text" THEN 'RTS taxonomy'::"text"
            WHEN 'EO-K-004'::"text" THEN 'Decision ecology'::"text"
            WHEN 'EO-K-006'::"text" THEN 'Performance quality'::"text"
            WHEN 'EO-LOSCIALE-2019-01'::"text" THEN 'Criteria validity'::"text"
            WHEN 'EO-LOSCIALE-2019-02'::"text" THEN 'Uncertain protection'::"text"
            WHEN 'EO-LOSCIALE-2019-05'::"text" THEN 'Construct heterogeneity'::"text"
            WHEN 'EO-LOSCIALE-2019-06'::"text" THEN 'Missing domain'::"text"
            WHEN 'EO-MEIERBACHTOL-2018-03'::"text" THEN 'Threshold sensitivity'::"text"
            WHEN 'EO-MEIERBACHTOL-2018-04'::"text" THEN 'Construct separation'::"text"
            WHEN 'EO-myer2006-02'::"text" THEN 'Protocol drift risk'::"text"
            WHEN 'EO-myer2006-03'::"text" THEN 'Framework, not proof'::"text"
            WHEN 'EO-myer2006-06'::"text" THEN 'Author boundary'::"text"
            WHEN 'EO-P24-02'::"text" THEN 'Timing with caution'::"text"
            WHEN 'EO-P24-05'::"text" THEN 'Method inconsistency'::"text"
            WHEN 'EO-P24-06'::"text" THEN 'Certainty discipline'::"text"
            WHEN 'EO-TOOLE-01'::"text" THEN 'Clearance gap'::"text"
            WHEN 'EO-TOOLE-02'::"text" THEN 'Capacity signal'::"text"
            WHEN 'EO-VM-03'::"text" THEN 'LSI denominator problem'::"text"
            ELSE COALESCE("pec"."evidence_role", 'Evidence object'::"text")
        END AS "learning_frame",
    "pec"."public_finding",
    "pec"."public_boundary",
    "pec"."public_framework_application",
    "pec"."public_open_question",
    "pec"."source_supports",
    "pec"."source_does_not_establish",
    "pec"."evidence_role",
    "pec"."confidence_level",
    "pec"."uncertainty_flag",
    "pec"."risk_category",
    "pec"."human_review_status",
    "pec"."curation_status",
    "pec"."approved_for_public",
    "pec"."blocked_language_flag",
    "pec"."replacement_risk_status",
    "pec"."source_traceability_status",
    "pec"."boundary_review_status",
        CASE
            WHEN ("pec"."blocked_language_flag" = true) THEN 'blocked'::"text"
            WHEN ("pec"."curation_status" ~~ '%polished%'::"text") THEN 'polished'::"text"
            ELSE 'needs final source check'::"text"
        END AS "showcase_status"
   FROM (("public"."prism_evidence_curation" "pec"
     LEFT JOIN "public"."evidence_objects" "eo" ON (("eo"."evidence_id" = "pec"."evidence_id")))
     LEFT JOIN "public"."sources" "s" ON (("s"."source_id" = "eo"."source_id")))
  WHERE ("pec"."evidence_id" = ANY (ARRAY['EO-AGU-01'::"text", 'EO-AGU-02'::"text", 'EO-AGU-03'::"text", 'EO-AGU-05'::"text", 'EO-AGU-06'::"text", 'EO-1'::"text", 'EO-2'::"text", 'EO-5'::"text", 'EO-6'::"text", 'EO-DS01'::"text", 'EO-DS02'::"text", 'EO-DS04'::"text", 'EO-K-001'::"text", 'EO-K-004'::"text", 'EO-K-006'::"text", 'EO-LOSCIALE-2019-01'::"text", 'EO-LOSCIALE-2019-02'::"text", 'EO-LOSCIALE-2019-05'::"text", 'EO-LOSCIALE-2019-06'::"text", 'EO-MEIERBACHTOL-2018-03'::"text", 'EO-MEIERBACHTOL-2018-04'::"text", 'EO-myer2006-02'::"text", 'EO-myer2006-03'::"text", 'EO-myer2006-06'::"text", 'EO-P24-02'::"text", 'EO-P24-05'::"text", 'EO-P24-06'::"text", 'EO-TOOLE-01'::"text", 'EO-TOOLE-02'::"text", 'EO-VM-03'::"text"]));


ALTER VIEW "public"."prism_showcase_evidence_cards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."source_construct_links" (
    "source_id" "text" NOT NULL,
    "construct_id" "text" NOT NULL,
    "construct_family" "text"
);


ALTER TABLE "public"."source_construct_links" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."source_overview" AS
 SELECT "s"."source_id",
    "s"."title",
    "s"."citation",
    "s"."doi",
    "s"."journal",
    "s"."year",
    "s"."source_type",
    "s"."population_scope",
    "count"(DISTINCT "eo"."evidence_id") AS "evidence_object_count",
    "count"(DISTINCT "bn"."boundary_id") AS "boundary_note_count",
    "count"(DISTINCT "cp"."prompt_id") AS "curiosity_prompt_count"
   FROM ((("public"."sources" "s"
     LEFT JOIN "public"."evidence_objects" "eo" ON (("s"."source_id" = "eo"."source_id")))
     LEFT JOIN "public"."boundary_notes" "bn" ON (("s"."source_id" = "bn"."source_id")))
     LEFT JOIN "public"."curiosity_prompts" "cp" ON (("s"."source_id" = "cp"."source_id")))
  GROUP BY "s"."source_id", "s"."title", "s"."citation", "s"."doi", "s"."journal", "s"."year", "s"."source_type", "s"."population_scope";


ALTER VIEW "public"."source_overview" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."source_role_assignments" (
    "source_id" "text" NOT NULL,
    "concept_zone" "text" NOT NULL,
    "source_role" "text" NOT NULL,
    "role_rationale" "text",
    "review_status" "text" DEFAULT 'needs_review'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."source_role_assignments" OWNER TO "postgres";


ALTER TABLE ONLY "prism_core"."app_acl_rts_student_payload_v01_audit_log" ALTER COLUMN "audit_id" SET DEFAULT "nextval"('"prism_core"."app_acl_rts_student_payload_v01_audit_log_audit_id_seq"'::"regclass");



ALTER TABLE ONLY "prism_core"."mvp_release_changelog_v01" ALTER COLUMN "changelog_id" SET DEFAULT "nextval"('"prism_core"."mvp_release_changelog_v01_changelog_id_seq"'::"regclass");



ALTER TABLE ONLY "prism_audit"."card_refinement_workspace"
    ADD CONSTRAINT "card_refinement_workspace_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_api_v01"
    ADD CONSTRAINT "app_acl_rts_card_api_v01_pk" PRIMARY KEY ("ui_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_bridge_api_v01"
    ADD CONSTRAINT "app_acl_rts_card_bridge_api_v01_pkey" PRIMARY KEY ("bridge_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_presentation_v01"
    ADD CONSTRAINT "app_acl_rts_card_presentation_v01_pkey" PRIMARY KEY ("ui_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_tag_map_v01"
    ADD CONSTRAINT "app_acl_rts_card_tag_map_v01_pkey" PRIMARY KEY ("ui_order", "tag_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_concept_tag_api_v01"
    ADD CONSTRAINT "app_acl_rts_concept_tag_api_v01_pkey" PRIMARY KEY ("tag_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_learning_path_cards_v01"
    ADD CONSTRAINT "app_acl_rts_learning_path_cards_v01_pkey" PRIMARY KEY ("path_id", "path_step");



ALTER TABLE ONLY "prism_core"."app_acl_rts_learning_paths_v01"
    ADD CONSTRAINT "app_acl_rts_learning_paths_v01_pkey" PRIMARY KEY ("path_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_mvp_cards_v01"
    ADD CONSTRAINT "app_acl_rts_mvp_cards_v01_pk" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_mvp_copy_v01"
    ADD CONSTRAINT "app_acl_rts_mvp_copy_v01_pkey" PRIMARY KEY ("release_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_mvp_sections_v01"
    ADD CONSTRAINT "app_acl_rts_mvp_sections_v01_pkey" PRIMARY KEY ("section_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_source_api_v01"
    ADD CONSTRAINT "app_acl_rts_source_api_v01_pk" PRIMARY KEY ("source_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_student_payload_v01_audit_log"
    ADD CONSTRAINT "app_acl_rts_student_payload_v01_audit_log_pkey" PRIMARY KEY ("audit_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_student_payload_v01"
    ADD CONSTRAINT "app_acl_rts_student_payload_v01_pk" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "prism_core"."concept_zones"
    ADD CONSTRAINT "concept_zones_pkey" PRIMARY KEY ("concept_zone_id");



ALTER TABLE ONLY "prism_core"."database_visual_map_v01"
    ADD CONSTRAINT "database_visual_map_v01_pkey" PRIMARY KEY ("map_id");



ALTER TABLE ONLY "prism_core"."evidence_cards"
    ADD CONSTRAINT "evidence_cards_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "prism_core"."mvp_card_review_status_v01"
    ADD CONSTRAINT "mvp_card_review_status_v01_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "prism_core"."mvp_database_readme_v01"
    ADD CONSTRAINT "mvp_database_readme_v01_pkey" PRIMARY KEY ("object_name");



ALTER TABLE ONLY "prism_core"."mvp_migration_log_v01"
    ADD CONSTRAINT "mvp_migration_log_v01_pkey" PRIMARY KEY ("migration_id");



ALTER TABLE ONLY "prism_core"."mvp_release_changelog_v01"
    ADD CONSTRAINT "mvp_release_changelog_v01_pkey" PRIMARY KEY ("changelog_id");



ALTER TABLE ONLY "prism_core"."mvp_release_status"
    ADD CONSTRAINT "mvp_release_status_pkey" PRIMARY KEY ("release_id");



ALTER TABLE ONLY "prism_core"."prototype_connection_contract_v01"
    ADD CONSTRAINT "prototype_connection_contract_v01_pkey" PRIMARY KEY ("contract_id");



ALTER TABLE ONLY "prism_core"."release_acl_rts_mvp_v0_1_snapshot"
    ADD CONSTRAINT "release_acl_rts_mvp_v0_1_snapshot_pk" PRIMARY KEY ("ui_order");



ALTER TABLE ONLY "prism_core"."sources"
    ADD CONSTRAINT "sources_pkey" PRIMARY KEY ("source_id");



ALTER TABLE ONLY "prism_editor"."mvp_card_rewrites_12"
    ADD CONSTRAINT "mvp_card_rewrites_12_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "prism_editor"."refinement_drafts"
    ADD CONSTRAINT "refinement_drafts_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "public"."boundary_notes"
    ADD CONSTRAINT "boundary_notes_pkey" PRIMARY KEY ("boundary_id");



ALTER TABLE ONLY "public"."concept_zones"
    ADD CONSTRAINT "concept_zones_pkey" PRIMARY KEY ("concept_zone");



ALTER TABLE ONLY "public"."constructs"
    ADD CONSTRAINT "constructs_pkey" PRIMARY KEY ("construct_id");



ALTER TABLE ONLY "public"."curiosity_prompts"
    ADD CONSTRAINT "curiosity_prompts_pkey" PRIMARY KEY ("prompt_id");



ALTER TABLE ONLY "public"."evidence_construct_links"
    ADD CONSTRAINT "evidence_construct_links_pkey" PRIMARY KEY ("evidence_id", "construct_id");



ALTER TABLE ONLY "public"."evidence_objects"
    ADD CONSTRAINT "evidence_objects_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "public"."flow_links"
    ADD CONSTRAINT "flow_links_pkey" PRIMARY KEY ("flow_link_id");



ALTER TABLE ONLY "public"."guardrails"
    ADD CONSTRAINT "guardrails_pkey" PRIMARY KEY ("guardrail_id");



ALTER TABLE ONLY "public"."mvp_views"
    ADD CONSTRAINT "mvp_views_pkey" PRIMARY KEY ("view_id");



ALTER TABLE ONLY "public"."prism_evidence_curation"
    ADD CONSTRAINT "prism_evidence_curation_pkey" PRIMARY KEY ("evidence_id");



ALTER TABLE ONLY "public"."source_construct_links"
    ADD CONSTRAINT "source_construct_links_pkey" PRIMARY KEY ("source_id", "construct_id");



ALTER TABLE ONLY "public"."source_role_assignments"
    ADD CONSTRAINT "source_role_assignments_pkey" PRIMARY KEY ("source_id", "concept_zone");



ALTER TABLE ONLY "public"."sources"
    ADD CONSTRAINT "sources_pkey" PRIMARY KEY ("source_id");



CREATE INDEX "idx_app_acl_rts_card_api_v01_release_order" ON "prism_core"."app_acl_rts_card_api_v01" USING "btree" ("release_id", "ui_order");



CREATE INDEX "idx_app_acl_rts_card_api_v01_zone" ON "prism_core"."app_acl_rts_card_api_v01" USING "btree" ("concept_zone");



CREATE INDEX "idx_app_acl_rts_card_bridge_api_v01_from" ON "prism_core"."app_acl_rts_card_bridge_api_v01" USING "btree" ("from_ui_order");



CREATE INDEX "idx_app_acl_rts_card_bridge_api_v01_release_order" ON "prism_core"."app_acl_rts_card_bridge_api_v01" USING "btree" ("release_id", "bridge_order");



CREATE INDEX "idx_app_acl_rts_card_bridge_api_v01_to" ON "prism_core"."app_acl_rts_card_bridge_api_v01" USING "btree" ("to_ui_order");



CREATE INDEX "idx_app_acl_rts_mvp_cards_v01_release_order" ON "prism_core"."app_acl_rts_mvp_cards_v01" USING "btree" ("release_id", "display_order");



CREATE INDEX "idx_app_acl_rts_mvp_cards_v01_source" ON "prism_core"."app_acl_rts_mvp_cards_v01" USING "btree" ("source_title");



CREATE INDEX "idx_app_acl_rts_mvp_cards_v01_zone" ON "prism_core"."app_acl_rts_mvp_cards_v01" USING "btree" ("concept_zone");



CREATE INDEX "idx_app_acl_rts_source_api_v01_order" ON "prism_core"."app_acl_rts_source_api_v01" USING "btree" ("source_order");



CREATE INDEX "idx_app_acl_rts_source_api_v01_role" ON "prism_core"."app_acl_rts_source_api_v01" USING "btree" ("locked_source_role");



CREATE OR REPLACE TRIGGER "prevent_app_payload_delete" BEFORE DELETE ON "prism_core"."app_acl_rts_student_payload_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_app_payload_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_app_payload_update" BEFORE UPDATE ON "prism_core"."app_acl_rts_student_payload_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_app_payload_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_bridge_api_delete" BEFORE DELETE ON "prism_core"."app_acl_rts_card_bridge_api_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_bridge_api_update" BEFORE UPDATE ON "prism_core"."app_acl_rts_card_bridge_api_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_card_api_delete" BEFORE DELETE ON "prism_core"."app_acl_rts_card_api_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_card_api_update" BEFORE UPDATE ON "prism_core"."app_acl_rts_card_api_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_card_presentation_delete" BEFORE DELETE ON "prism_core"."app_acl_rts_card_presentation_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_card_presentation_update" BEFORE UPDATE ON "prism_core"."app_acl_rts_card_presentation_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_release_snapshot_delete" BEFORE DELETE ON "prism_core"."release_acl_rts_mvp_v0_1_snapshot" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_release_snapshot_update" BEFORE UPDATE ON "prism_core"."release_acl_rts_mvp_v0_1_snapshot" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_source_api_delete" BEFORE DELETE ON "prism_core"."app_acl_rts_source_api_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



CREATE OR REPLACE TRIGGER "prevent_source_api_update" BEFORE UPDATE ON "prism_core"."app_acl_rts_source_api_v01" FOR EACH ROW EXECUTE FUNCTION "prism_guard"."block_api_table_direct_changes"();



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_bridge_api_v01"
    ADD CONSTRAINT "app_acl_rts_card_bridge_api_v01_from_ui_order_fkey" FOREIGN KEY ("from_ui_order") REFERENCES "prism_core"."app_acl_rts_card_api_v01"("ui_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_bridge_api_v01"
    ADD CONSTRAINT "app_acl_rts_card_bridge_api_v01_to_ui_order_fkey" FOREIGN KEY ("to_ui_order") REFERENCES "prism_core"."app_acl_rts_card_api_v01"("ui_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_presentation_v01"
    ADD CONSTRAINT "app_acl_rts_card_presentation_v01_ui_order_fkey" FOREIGN KEY ("ui_order") REFERENCES "prism_core"."app_acl_rts_card_api_v01"("ui_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_tag_map_v01"
    ADD CONSTRAINT "app_acl_rts_card_tag_map_v01_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "prism_core"."app_acl_rts_concept_tag_api_v01"("tag_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_card_tag_map_v01"
    ADD CONSTRAINT "app_acl_rts_card_tag_map_v01_ui_order_fkey" FOREIGN KEY ("ui_order") REFERENCES "prism_core"."app_acl_rts_card_api_v01"("ui_order");



ALTER TABLE ONLY "prism_core"."app_acl_rts_learning_path_cards_v01"
    ADD CONSTRAINT "app_acl_rts_learning_path_cards_v01_path_id_fkey" FOREIGN KEY ("path_id") REFERENCES "prism_core"."app_acl_rts_learning_paths_v01"("path_id");



ALTER TABLE ONLY "prism_core"."app_acl_rts_learning_path_cards_v01"
    ADD CONSTRAINT "app_acl_rts_learning_path_cards_v01_ui_order_fkey" FOREIGN KEY ("ui_order") REFERENCES "prism_core"."app_acl_rts_card_api_v01"("ui_order");



ALTER TABLE ONLY "prism_core"."mvp_card_review_status_v01"
    ADD CONSTRAINT "mvp_card_review_status_v01_evidence_id_fkey" FOREIGN KEY ("evidence_id") REFERENCES "prism_core"."app_acl_rts_mvp_cards_v01"("evidence_id");



ALTER TABLE ONLY "public"."boundary_notes"
    ADD CONSTRAINT "boundary_notes_evidence_id_fkey" FOREIGN KEY ("evidence_id") REFERENCES "public"."evidence_objects"("evidence_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boundary_notes"
    ADD CONSTRAINT "boundary_notes_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."sources"("source_id");



ALTER TABLE ONLY "public"."curiosity_prompts"
    ADD CONSTRAINT "curiosity_prompts_evidence_id_fkey" FOREIGN KEY ("evidence_id") REFERENCES "public"."evidence_objects"("evidence_id");



ALTER TABLE ONLY "public"."curiosity_prompts"
    ADD CONSTRAINT "curiosity_prompts_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."sources"("source_id");



ALTER TABLE ONLY "public"."evidence_construct_links"
    ADD CONSTRAINT "evidence_construct_links_construct_id_fkey" FOREIGN KEY ("construct_id") REFERENCES "public"."constructs"("construct_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."evidence_construct_links"
    ADD CONSTRAINT "evidence_construct_links_evidence_id_fkey" FOREIGN KEY ("evidence_id") REFERENCES "public"."evidence_objects"("evidence_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."evidence_objects"
    ADD CONSTRAINT "evidence_objects_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."sources"("source_id");



ALTER TABLE ONLY "public"."flow_links"
    ADD CONSTRAINT "flow_links_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."sources"("source_id");



ALTER TABLE ONLY "public"."prism_evidence_curation"
    ADD CONSTRAINT "prism_evidence_curation_evidence_id_fkey" FOREIGN KEY ("evidence_id") REFERENCES "public"."evidence_objects"("evidence_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."source_construct_links"
    ADD CONSTRAINT "source_construct_links_construct_id_fkey" FOREIGN KEY ("construct_id") REFERENCES "public"."constructs"("construct_id");



ALTER TABLE ONLY "public"."source_construct_links"
    ADD CONSTRAINT "source_construct_links_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."sources"("source_id");



ALTER TABLE ONLY "public"."source_role_assignments"
    ADD CONSTRAINT "source_role_assignments_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."sources"("source_id") ON DELETE CASCADE;



ALTER TABLE "prism_audit"."card_refinement_workspace" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_card_api_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_card_bridge_api_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_card_presentation_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_card_tag_map_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_concept_tag_api_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_learning_path_cards_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_learning_paths_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_mvp_cards_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_mvp_cards_v01_backup" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_mvp_copy_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_mvp_sections_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_source_api_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_student_payload_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."app_acl_rts_student_payload_v01_audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."concept_zones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."database_visual_map_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."evidence_cards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."mvp_card_review_status_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."mvp_database_readme_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."mvp_migration_log_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."mvp_release_changelog_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."mvp_release_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."mvp_source_scope_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."prototype_connection_contract_v01" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."release_acl_rts_mvp_v0_1_snapshot" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."source_registry_locked" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_core"."sources" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_editor"."mvp_candidate_cards_12" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_editor"."mvp_card_rewrites_12" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "prism_editor"."refinement_drafts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Allow public read boundary notes" ON "public"."boundary_notes" FOR SELECT USING (true);



CREATE POLICY "Allow public read constructs" ON "public"."constructs" FOR SELECT USING (true);



CREATE POLICY "Allow public read curiosity prompts" ON "public"."curiosity_prompts" FOR SELECT USING (true);



CREATE POLICY "Allow public read evidence objects" ON "public"."evidence_objects" FOR SELECT USING (true);



CREATE POLICY "Allow public read flow links" ON "public"."flow_links" FOR SELECT USING (true);



CREATE POLICY "Allow public read guardrails" ON "public"."guardrails" FOR SELECT USING (true);



CREATE POLICY "Allow public read mvp views" ON "public"."mvp_views" FOR SELECT USING (true);



CREATE POLICY "Allow public read source construct links" ON "public"."source_construct_links" FOR SELECT USING (true);



CREATE POLICY "Allow public read sources" ON "public"."sources" FOR SELECT USING (true);



ALTER TABLE "public"."boundary_notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."concept_zones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."constructs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."curiosity_prompts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."evidence_construct_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."evidence_objects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."flow_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."guardrails" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mvp_views" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prism_evidence_curation" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."source_construct_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."source_role_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sources" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."search_evidence"("search_text" "text") TO "anon";


















GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_objects" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_objects" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_objects" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_evidence_curation" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_evidence_curation" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_evidence_curation" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sources" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sources" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sources" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boundary_notes" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boundary_notes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boundary_notes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boundary_filter" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boundary_filter" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boundary_filter" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."concept_zones" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."concept_zones" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."concept_zones" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."construct_explorer" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."construct_explorer" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."construct_explorer" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."constructs" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."constructs" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."constructs" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."curiosity_prompts" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."curiosity_prompts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."curiosity_prompts" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_boundary_browser" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_boundary_browser" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_boundary_browser" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_browser" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_browser" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_browser" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_construct_links" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_construct_links" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_construct_links" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_detail_with_boundaries" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_detail_with_boundaries" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_detail_with_boundaries" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."guardrails" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."guardrails" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."guardrails" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_with_guardrails" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_with_guardrails" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."evidence_with_guardrails" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."flow_links" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."flow_links" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."flow_links" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."mvp_views" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."mvp_views" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."mvp_views" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_curation_qa_dashboard" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_curation_qa_dashboard" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_curation_qa_dashboard" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_framework_inference_layer" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_framework_inference_layer" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_framework_inference_layer" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_human_curation_queue" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_human_curation_queue" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_human_curation_queue" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_mvp_usage_layer" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_mvp_usage_layer" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_mvp_usage_layer" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_public_evidence_objects" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_public_evidence_objects" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_public_evidence_objects" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_showcase_evidence_cards" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_showcase_evidence_cards" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."prism_showcase_evidence_cards" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_construct_links" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_construct_links" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_construct_links" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_overview" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_overview" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_overview" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_role_assignments" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_role_assignments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."source_role_assignments" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";































drop extension if exists "pg_net";

revoke delete on table "public"."boundary_notes" from "anon";

revoke insert on table "public"."boundary_notes" from "anon";

revoke update on table "public"."boundary_notes" from "anon";

revoke delete on table "public"."boundary_notes" from "authenticated";

revoke insert on table "public"."boundary_notes" from "authenticated";

revoke select on table "public"."boundary_notes" from "authenticated";

revoke update on table "public"."boundary_notes" from "authenticated";

revoke delete on table "public"."boundary_notes" from "service_role";

revoke insert on table "public"."boundary_notes" from "service_role";

revoke select on table "public"."boundary_notes" from "service_role";

revoke update on table "public"."boundary_notes" from "service_role";

revoke delete on table "public"."concept_zones" from "anon";

revoke insert on table "public"."concept_zones" from "anon";

revoke update on table "public"."concept_zones" from "anon";

revoke delete on table "public"."concept_zones" from "authenticated";

revoke insert on table "public"."concept_zones" from "authenticated";

revoke select on table "public"."concept_zones" from "authenticated";

revoke update on table "public"."concept_zones" from "authenticated";

revoke delete on table "public"."concept_zones" from "service_role";

revoke insert on table "public"."concept_zones" from "service_role";

revoke select on table "public"."concept_zones" from "service_role";

revoke update on table "public"."concept_zones" from "service_role";

revoke delete on table "public"."constructs" from "anon";

revoke insert on table "public"."constructs" from "anon";

revoke update on table "public"."constructs" from "anon";

revoke delete on table "public"."constructs" from "authenticated";

revoke insert on table "public"."constructs" from "authenticated";

revoke select on table "public"."constructs" from "authenticated";

revoke update on table "public"."constructs" from "authenticated";

revoke delete on table "public"."constructs" from "service_role";

revoke insert on table "public"."constructs" from "service_role";

revoke select on table "public"."constructs" from "service_role";

revoke update on table "public"."constructs" from "service_role";

revoke delete on table "public"."curiosity_prompts" from "anon";

revoke insert on table "public"."curiosity_prompts" from "anon";

revoke update on table "public"."curiosity_prompts" from "anon";

revoke delete on table "public"."curiosity_prompts" from "authenticated";

revoke insert on table "public"."curiosity_prompts" from "authenticated";

revoke select on table "public"."curiosity_prompts" from "authenticated";

revoke update on table "public"."curiosity_prompts" from "authenticated";

revoke delete on table "public"."curiosity_prompts" from "service_role";

revoke insert on table "public"."curiosity_prompts" from "service_role";

revoke select on table "public"."curiosity_prompts" from "service_role";

revoke update on table "public"."curiosity_prompts" from "service_role";

revoke delete on table "public"."evidence_construct_links" from "anon";

revoke insert on table "public"."evidence_construct_links" from "anon";

revoke update on table "public"."evidence_construct_links" from "anon";

revoke delete on table "public"."evidence_construct_links" from "authenticated";

revoke insert on table "public"."evidence_construct_links" from "authenticated";

revoke select on table "public"."evidence_construct_links" from "authenticated";

revoke update on table "public"."evidence_construct_links" from "authenticated";

revoke delete on table "public"."evidence_construct_links" from "service_role";

revoke insert on table "public"."evidence_construct_links" from "service_role";

revoke select on table "public"."evidence_construct_links" from "service_role";

revoke update on table "public"."evidence_construct_links" from "service_role";

revoke delete on table "public"."evidence_objects" from "anon";

revoke insert on table "public"."evidence_objects" from "anon";

revoke update on table "public"."evidence_objects" from "anon";

revoke delete on table "public"."evidence_objects" from "authenticated";

revoke insert on table "public"."evidence_objects" from "authenticated";

revoke select on table "public"."evidence_objects" from "authenticated";

revoke update on table "public"."evidence_objects" from "authenticated";

revoke delete on table "public"."evidence_objects" from "service_role";

revoke insert on table "public"."evidence_objects" from "service_role";

revoke select on table "public"."evidence_objects" from "service_role";

revoke update on table "public"."evidence_objects" from "service_role";

revoke delete on table "public"."flow_links" from "anon";

revoke insert on table "public"."flow_links" from "anon";

revoke update on table "public"."flow_links" from "anon";

revoke delete on table "public"."flow_links" from "authenticated";

revoke insert on table "public"."flow_links" from "authenticated";

revoke select on table "public"."flow_links" from "authenticated";

revoke update on table "public"."flow_links" from "authenticated";

revoke delete on table "public"."flow_links" from "service_role";

revoke insert on table "public"."flow_links" from "service_role";

revoke select on table "public"."flow_links" from "service_role";

revoke update on table "public"."flow_links" from "service_role";

revoke delete on table "public"."guardrails" from "anon";

revoke insert on table "public"."guardrails" from "anon";

revoke update on table "public"."guardrails" from "anon";

revoke delete on table "public"."guardrails" from "authenticated";

revoke insert on table "public"."guardrails" from "authenticated";

revoke select on table "public"."guardrails" from "authenticated";

revoke update on table "public"."guardrails" from "authenticated";

revoke delete on table "public"."guardrails" from "service_role";

revoke insert on table "public"."guardrails" from "service_role";

revoke select on table "public"."guardrails" from "service_role";

revoke update on table "public"."guardrails" from "service_role";

revoke delete on table "public"."mvp_views" from "anon";

revoke insert on table "public"."mvp_views" from "anon";

revoke update on table "public"."mvp_views" from "anon";

revoke delete on table "public"."mvp_views" from "authenticated";

revoke insert on table "public"."mvp_views" from "authenticated";

revoke select on table "public"."mvp_views" from "authenticated";

revoke update on table "public"."mvp_views" from "authenticated";

revoke delete on table "public"."mvp_views" from "service_role";

revoke insert on table "public"."mvp_views" from "service_role";

revoke select on table "public"."mvp_views" from "service_role";

revoke update on table "public"."mvp_views" from "service_role";

revoke delete on table "public"."prism_evidence_curation" from "anon";

revoke insert on table "public"."prism_evidence_curation" from "anon";

revoke update on table "public"."prism_evidence_curation" from "anon";

revoke delete on table "public"."prism_evidence_curation" from "authenticated";

revoke insert on table "public"."prism_evidence_curation" from "authenticated";

revoke select on table "public"."prism_evidence_curation" from "authenticated";

revoke update on table "public"."prism_evidence_curation" from "authenticated";

revoke delete on table "public"."prism_evidence_curation" from "service_role";

revoke insert on table "public"."prism_evidence_curation" from "service_role";

revoke select on table "public"."prism_evidence_curation" from "service_role";

revoke update on table "public"."prism_evidence_curation" from "service_role";

revoke delete on table "public"."source_construct_links" from "anon";

revoke insert on table "public"."source_construct_links" from "anon";

revoke update on table "public"."source_construct_links" from "anon";

revoke delete on table "public"."source_construct_links" from "authenticated";

revoke insert on table "public"."source_construct_links" from "authenticated";

revoke select on table "public"."source_construct_links" from "authenticated";

revoke update on table "public"."source_construct_links" from "authenticated";

revoke delete on table "public"."source_construct_links" from "service_role";

revoke insert on table "public"."source_construct_links" from "service_role";

revoke select on table "public"."source_construct_links" from "service_role";

revoke update on table "public"."source_construct_links" from "service_role";

revoke delete on table "public"."source_role_assignments" from "anon";

revoke insert on table "public"."source_role_assignments" from "anon";

revoke update on table "public"."source_role_assignments" from "anon";

revoke delete on table "public"."source_role_assignments" from "authenticated";

revoke insert on table "public"."source_role_assignments" from "authenticated";

revoke select on table "public"."source_role_assignments" from "authenticated";

revoke update on table "public"."source_role_assignments" from "authenticated";

revoke delete on table "public"."source_role_assignments" from "service_role";

revoke insert on table "public"."source_role_assignments" from "service_role";

revoke select on table "public"."source_role_assignments" from "service_role";

revoke update on table "public"."source_role_assignments" from "service_role";

revoke delete on table "public"."sources" from "anon";

revoke insert on table "public"."sources" from "anon";

revoke update on table "public"."sources" from "anon";

revoke delete on table "public"."sources" from "authenticated";

revoke insert on table "public"."sources" from "authenticated";

revoke select on table "public"."sources" from "authenticated";

revoke update on table "public"."sources" from "authenticated";

revoke delete on table "public"."sources" from "service_role";

revoke insert on table "public"."sources" from "service_role";

revoke select on table "public"."sources" from "service_role";

revoke update on table "public"."sources" from "service_role";


