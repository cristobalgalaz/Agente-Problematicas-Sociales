--
-- PostgreSQL database dump
--

\restrict qCtWSxDcsuQyLVteZY38dMDzBCOPVExjbwZ3fPEqvcZXDXjCOU3LTUQ7EGmtkiS

-- Dumped from database version 17.9 (Debian 17.9-1.pgdg13+1)
-- Dumped by pg_dump version 17.9

-- Started on 2026-04-06 00:51:01

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 16456)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 4293 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 439 (class 1255 OID 16433)
-- Name: fn_auditoria_insert(); Type: FUNCTION; Schema: public; Owner: agente_user
--

CREATE FUNCTION public.fn_auditoria_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO auditoria_problematicas(
        id_problematica, accion, fecha_cambio, datos_nuevos
    )
    VALUES(
        NEW.id, 'INSERT', NOW(),
        CONCAT('Título: ', NEW.titulo,
               ' | Área social: ', NEW.area_social)
    );
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_auditoria_insert() OWNER TO agente_user;

--
-- TOC entry 440 (class 1255 OID 16453)
-- Name: fn_auditoria_update(); Type: FUNCTION; Schema: public; Owner: agente_user
--

CREATE FUNCTION public.fn_auditoria_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO auditoria_problematicas(
        id_problematica, accion, fecha_cambio,
        datos_anteriores, datos_nuevos
    )
    VALUES(
        OLD.id, 'UPDATE', NOW(),
        CONCAT('Título: ', OLD.titulo,
               ' | Área social: ', OLD.area_social),
        CONCAT('Título: ', NEW.titulo,
               ' | Área social: ', NEW.area_social)
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_auditoria_update() OWNER TO agente_user;

--
-- TOC entry 451 (class 1255 OID 17866)
-- Name: increment_workflow_version(); Type: FUNCTION; Schema: public; Owner: agente_user
--

CREATE FUNCTION public.increment_workflow_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
			BEGIN
				IF NEW."versionCounter" IS NOT DISTINCT FROM OLD."versionCounter" THEN
					NEW."versionCounter" = OLD."versionCounter" + 1;
				END IF;
				RETURN NEW;
			END;
			$$;


ALTER FUNCTION public.increment_workflow_version() OWNER TO agente_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 349 (class 1259 OID 16390)
-- Name: problematicas; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.problematicas (
    id integer NOT NULL,
    titulo text,
    descripcion text,
    area_social text,
    area_tecnologica text,
    solucion text,
    url_fuente text,
    fecha_analisis timestamp without time zone DEFAULT now()
);


ALTER TABLE public.problematicas OWNER TO agente_user;

--
-- TOC entry 354 (class 1259 OID 16434)
-- Name: v_problematicas_completas; Type: VIEW; Schema: public; Owner: agente_user
--

CREATE VIEW public.v_problematicas_completas AS
 SELECT id,
    titulo,
    descripcion,
    area_social,
    area_tecnologica,
    solucion,
        CASE
            WHEN ((solucion IS NOT NULL) AND (solucion <> ''::text) AND (solucion <> 'N/A'::text)) THEN true
            ELSE false
        END AS tiene_solucion,
    url_fuente,
    fecha_analisis,
    date_part('day'::text, (now() - (fecha_analisis)::timestamp with time zone)) AS dias_desde_analisis,
        CASE
            WHEN ((area_social IS NOT NULL) AND (area_social <> 'N/A'::text)) THEN true
            ELSE false
        END AS tiene_area_social,
        CASE
            WHEN ((area_tecnologica IS NOT NULL) AND (area_tecnologica <> 'N/A'::text)) THEN true
            ELSE false
        END AS tiene_area_tecnologica,
    length(descripcion) AS longitud_descripcion
   FROM public.problematicas
  ORDER BY fecha_analisis DESC;


ALTER VIEW public.v_problematicas_completas OWNER TO agente_user;

--
-- TOC entry 4294 (class 0 OID 0)
-- Dependencies: 354
-- Name: VIEW v_problematicas_completas; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON VIEW public.v_problematicas_completas IS 'Vista consolidada con todos los campos necesarios para el frontend. Incluye campos calculados como días desde análisis y flags booleanos para validaciones.';


--
-- TOC entry 438 (class 1255 OID 16440)
-- Name: sp_buscar_problematicas(character varying, character varying); Type: FUNCTION; Schema: public; Owner: agente_user
--

CREATE FUNCTION public.sp_buscar_problematicas(p_area_social character varying DEFAULT NULL::character varying, p_keyword character varying DEFAULT NULL::character varying) RETURNS SETOF public.v_problematicas_completas
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM v_problematicas_completas
    WHERE
        -- Filtro opcional por área social
        (p_area_social IS NULL OR area_social = p_area_social)
        AND
        -- Filtro opcional por palabra clave en título
        (p_keyword IS NULL OR titulo ILIKE '%' || p_keyword || '%');
END;
$$;


ALTER FUNCTION public.sp_buscar_problematicas(p_area_social character varying, p_keyword character varying) OWNER TO agente_user;

--
-- TOC entry 463 (class 1255 OID 18600)
-- Name: sp_insertar_problematica(character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: agente_user
--

CREATE FUNCTION public.sp_insertar_problematica(p_titulo character varying, p_descripcion character varying, p_area_social character varying, p_area_tecnologica character varying, p_solucion character varying, p_url character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_existente problematicas%ROWTYPE;
BEGIN
    SELECT * INTO v_existente
    FROM problematicas
    WHERE url_fuente = p_url;

    IF FOUND THEN
        INSERT INTO problematicas_duplicados (titulo, descripcion, area_social, area_tecnologica, solucion, url_fuente, motivo)
        VALUES (v_existente.titulo, v_existente.descripcion, v_existente.area_social,
                v_existente.area_tecnologica, v_existente.solucion, v_existente.url_fuente,
                'Reemplazado por versión más reciente');

        UPDATE problematicas SET
            titulo           = p_titulo,
            descripcion      = p_descripcion,
            area_social      = p_area_social,
            area_tecnologica = p_area_tecnologica,
            solucion         = p_solucion,
            fecha_analisis   = NOW()  -- ← actualizar fecha
        WHERE url_fuente = p_url;
    ELSE
        INSERT INTO problematicas (titulo, descripcion, area_social, area_tecnologica, solucion, url_fuente)
        VALUES (p_titulo, p_descripcion, p_area_social, p_area_tecnologica, p_solucion, p_url);
    END IF;
END;
$$;


ALTER FUNCTION public.sp_insertar_problematica(p_titulo character varying, p_descripcion character varying, p_area_social character varying, p_area_tecnologica character varying, p_solucion character varying, p_url character varying) OWNER TO agente_user;

--
-- TOC entry 387 (class 1259 OID 17234)
-- Name: annotation_tag_entity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.annotation_tag_entity (
    id character varying(16) NOT NULL,
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.annotation_tag_entity OWNER TO agente_user;

--
-- TOC entry 356 (class 1259 OID 16443)
-- Name: auditoria_problematicas; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.auditoria_problematicas (
    id integer NOT NULL,
    id_problematica integer,
    accion character varying(20),
    fecha_cambio timestamp without time zone DEFAULT now(),
    datos_nuevos text,
    datos_anteriores text
);


ALTER TABLE public.auditoria_problematicas OWNER TO agente_user;

--
-- TOC entry 355 (class 1259 OID 16442)
-- Name: auditoria_problematicas_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.auditoria_problematicas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auditoria_problematicas_id_seq OWNER TO agente_user;

--
-- TOC entry 4295 (class 0 OID 0)
-- Dependencies: 355
-- Name: auditoria_problematicas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.auditoria_problematicas_id_seq OWNED BY public.auditoria_problematicas.id;


--
-- TOC entry 372 (class 1259 OID 16761)
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.auth_identity (
    "userId" uuid,
    "providerId" character varying(255) NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.auth_identity OWNER TO agente_user;

--
-- TOC entry 374 (class 1259 OID 16774)
-- Name: auth_provider_sync_history; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.auth_provider_sync_history (
    id integer NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "runMode" text NOT NULL,
    status text NOT NULL,
    "startedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "endedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scanned integer NOT NULL,
    created integer NOT NULL,
    updated integer NOT NULL,
    disabled integer NOT NULL,
    error text
);


ALTER TABLE public.auth_provider_sync_history OWNER TO agente_user;

--
-- TOC entry 373 (class 1259 OID 16773)
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.auth_provider_sync_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNER TO agente_user;

--
-- TOC entry 4296 (class 0 OID 0)
-- Dependencies: 373
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNED BY public.auth_provider_sync_history.id;


--
-- TOC entry 417 (class 1259 OID 17887)
-- Name: binary_data; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.binary_data (
    "fileId" uuid NOT NULL,
    "sourceType" character varying(50) NOT NULL,
    "sourceId" character varying(255) NOT NULL,
    data bytea NOT NULL,
    "mimeType" character varying(255),
    "fileName" character varying(255),
    "fileSize" integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_binary_data_sourceType" CHECK ((("sourceType")::text = ANY ((ARRAY['execution'::character varying, 'chat_message_attachment'::character varying])::text[])))
);


ALTER TABLE public.binary_data OWNER TO agente_user;

--
-- TOC entry 4297 (class 0 OID 0)
-- Dependencies: 417
-- Name: COLUMN binary_data."sourceType"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.binary_data."sourceType" IS 'Source the file belongs to, e.g. ''execution''';


--
-- TOC entry 4298 (class 0 OID 0)
-- Dependencies: 417
-- Name: COLUMN binary_data."sourceId"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.binary_data."sourceId" IS 'ID of the source, e.g. execution ID';


--
-- TOC entry 4299 (class 0 OID 0)
-- Dependencies: 417
-- Name: COLUMN binary_data.data; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.binary_data.data IS 'Raw, not base64 encoded';


--
-- TOC entry 4300 (class 0 OID 0)
-- Dependencies: 417
-- Name: COLUMN binary_data."fileSize"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.binary_data."fileSize" IS 'In bytes';


--
-- TOC entry 435 (class 1259 OID 18776)
-- Name: catalogo_area_social; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.catalogo_area_social (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.catalogo_area_social OWNER TO agente_user;

--
-- TOC entry 434 (class 1259 OID 18775)
-- Name: catalogo_area_social_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.catalogo_area_social_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.catalogo_area_social_id_seq OWNER TO agente_user;

--
-- TOC entry 4301 (class 0 OID 0)
-- Dependencies: 434
-- Name: catalogo_area_social_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.catalogo_area_social_id_seq OWNED BY public.catalogo_area_social.id;


--
-- TOC entry 437 (class 1259 OID 18785)
-- Name: catalogo_area_tecnologica; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.catalogo_area_tecnologica (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.catalogo_area_tecnologica OWNER TO agente_user;

--
-- TOC entry 436 (class 1259 OID 18784)
-- Name: catalogo_area_tecnologica_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.catalogo_area_tecnologica_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.catalogo_area_tecnologica_id_seq OWNER TO agente_user;

--
-- TOC entry 4302 (class 0 OID 0)
-- Dependencies: 436
-- Name: catalogo_area_tecnologica_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.catalogo_area_tecnologica_id_seq OWNED BY public.catalogo_area_tecnologica.id;


--
-- TOC entry 430 (class 1259 OID 18143)
-- Name: chat_hub_agent_tools; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.chat_hub_agent_tools (
    "agentId" uuid NOT NULL,
    "toolId" uuid NOT NULL
);


ALTER TABLE public.chat_hub_agent_tools OWNER TO agente_user;

--
-- TOC entry 408 (class 1259 OID 17738)
-- Name: chat_hub_agents; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.chat_hub_agents (
    id uuid NOT NULL,
    name character varying(256) NOT NULL,
    description character varying(512),
    "systemPrompt" text NOT NULL,
    "ownerId" uuid NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16) NOT NULL,
    model character varying(64) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json
);


ALTER TABLE public.chat_hub_agents OWNER TO agente_user;

--
-- TOC entry 4303 (class 0 OID 0)
-- Dependencies: 408
-- Name: COLUMN chat_hub_agents.provider; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_agents.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- TOC entry 4304 (class 0 OID 0)
-- Dependencies: 408
-- Name: COLUMN chat_hub_agents.model; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_agents.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- TOC entry 407 (class 1259 OID 17692)
-- Name: chat_hub_messages; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.chat_hub_messages (
    id uuid NOT NULL,
    "sessionId" uuid NOT NULL,
    "previousMessageId" uuid,
    "revisionOfMessageId" uuid,
    "retryOfMessageId" uuid,
    type character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    content text NOT NULL,
    provider character varying(16),
    model character varying(256),
    "workflowId" character varying(36),
    "executionId" integer,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" uuid,
    status character varying(16) DEFAULT 'success'::character varying NOT NULL,
    attachments json
);


ALTER TABLE public.chat_hub_messages OWNER TO agente_user;

--
-- TOC entry 4305 (class 0 OID 0)
-- Dependencies: 407
-- Name: COLUMN chat_hub_messages.type; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_messages.type IS 'ChatHubMessageType enum: "human", "ai", "system", "tool", "generic"';


--
-- TOC entry 4306 (class 0 OID 0)
-- Dependencies: 407
-- Name: COLUMN chat_hub_messages.provider; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_messages.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- TOC entry 4307 (class 0 OID 0)
-- Dependencies: 407
-- Name: COLUMN chat_hub_messages.model; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_messages.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- TOC entry 4308 (class 0 OID 0)
-- Dependencies: 407
-- Name: COLUMN chat_hub_messages."agentId"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_messages."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- TOC entry 4309 (class 0 OID 0)
-- Dependencies: 407
-- Name: COLUMN chat_hub_messages.status; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_messages.status IS 'ChatHubMessageStatus enum, eg. "success", "error", "running", "cancelled"';


--
-- TOC entry 4310 (class 0 OID 0)
-- Dependencies: 407
-- Name: COLUMN chat_hub_messages.attachments; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_messages.attachments IS 'File attachments for the message (if any), stored as JSON. Files are stored as base64-encoded data URLs.';


--
-- TOC entry 429 (class 1259 OID 18128)
-- Name: chat_hub_session_tools; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.chat_hub_session_tools (
    "sessionId" uuid NOT NULL,
    "toolId" uuid NOT NULL
);


ALTER TABLE public.chat_hub_session_tools OWNER TO agente_user;

--
-- TOC entry 406 (class 1259 OID 17670)
-- Name: chat_hub_sessions; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.chat_hub_sessions (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    "ownerId" uuid NOT NULL,
    "lastMessageAt" timestamp(3) with time zone NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16),
    model character varying(256),
    "workflowId" character varying(36),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" uuid,
    "agentName" character varying(128)
);


ALTER TABLE public.chat_hub_sessions OWNER TO agente_user;

--
-- TOC entry 4311 (class 0 OID 0)
-- Dependencies: 406
-- Name: COLUMN chat_hub_sessions.provider; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_sessions.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- TOC entry 4312 (class 0 OID 0)
-- Dependencies: 406
-- Name: COLUMN chat_hub_sessions.model; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_sessions.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- TOC entry 4313 (class 0 OID 0)
-- Dependencies: 406
-- Name: COLUMN chat_hub_sessions."agentId"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_sessions."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- TOC entry 4314 (class 0 OID 0)
-- Dependencies: 406
-- Name: COLUMN chat_hub_sessions."agentName"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.chat_hub_sessions."agentName" IS 'Cached name of the custom agent (if provider is "custom-agent")';


--
-- TOC entry 428 (class 1259 OID 18112)
-- Name: chat_hub_tools; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.chat_hub_tools (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255) NOT NULL,
    "typeVersion" double precision NOT NULL,
    "ownerId" uuid NOT NULL,
    definition json NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.chat_hub_tools OWNER TO agente_user;

--
-- TOC entry 359 (class 1259 OID 16477)
-- Name: credentials_entity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.credentials_entity (
    name character varying(128) NOT NULL,
    data text NOT NULL,
    type character varying(128) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL,
    "isManaged" boolean DEFAULT false NOT NULL,
    "isGlobal" boolean DEFAULT false NOT NULL,
    "isResolvable" boolean DEFAULT false NOT NULL,
    "resolvableAllowFallback" boolean DEFAULT false NOT NULL,
    "resolverId" character varying(16)
);


ALTER TABLE public.credentials_entity OWNER TO agente_user;

--
-- TOC entry 404 (class 1259 OID 17620)
-- Name: data_table; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.data_table (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table OWNER TO agente_user;

--
-- TOC entry 405 (class 1259 OID 17634)
-- Name: data_table_column; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.data_table_column (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(32) NOT NULL,
    index integer NOT NULL,
    "dataTableId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table_column OWNER TO agente_user;

--
-- TOC entry 4315 (class 0 OID 0)
-- Dependencies: 405
-- Name: COLUMN data_table_column.type; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.data_table_column.type IS 'Expected: string, number, boolean, or date (not enforced as a constraint)';


--
-- TOC entry 4316 (class 0 OID 0)
-- Dependencies: 405
-- Name: COLUMN data_table_column.index; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.data_table_column.index IS 'Column order, starting from 0 (0 = first column)';


--
-- TOC entry 427 (class 1259 OID 18091)
-- Name: dynamic_credential_entry; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.dynamic_credential_entry (
    credential_id character varying(16) NOT NULL,
    subject_id character varying(2048) NOT NULL,
    resolver_id character varying(16) NOT NULL,
    data text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_entry OWNER TO agente_user;

--
-- TOC entry 420 (class 1259 OID 17927)
-- Name: dynamic_credential_resolver; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.dynamic_credential_resolver (
    id character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(128) NOT NULL,
    config text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_resolver OWNER TO agente_user;

--
-- TOC entry 4317 (class 0 OID 0)
-- Dependencies: 420
-- Name: COLUMN dynamic_credential_resolver.config; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.dynamic_credential_resolver.config IS 'Encrypted resolver configuration (JSON encrypted as string)';


--
-- TOC entry 422 (class 1259 OID 18018)
-- Name: dynamic_credential_user_entry; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.dynamic_credential_user_entry (
    "credentialId" character varying(16) NOT NULL,
    "userId" uuid NOT NULL,
    "resolverId" character varying(16) NOT NULL,
    data text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_user_entry OWNER TO agente_user;

--
-- TOC entry 371 (class 1259 OID 16730)
-- Name: event_destinations; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.event_destinations (
    id uuid NOT NULL,
    destination jsonb NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.event_destinations OWNER TO agente_user;

--
-- TOC entry 388 (class 1259 OID 17242)
-- Name: execution_annotation_tags; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.execution_annotation_tags (
    "annotationId" integer NOT NULL,
    "tagId" character varying(24) NOT NULL
);


ALTER TABLE public.execution_annotation_tags OWNER TO agente_user;

--
-- TOC entry 386 (class 1259 OID 17218)
-- Name: execution_annotations; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.execution_annotations (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    vote character varying(6),
    note text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.execution_annotations OWNER TO agente_user;

--
-- TOC entry 385 (class 1259 OID 17217)
-- Name: execution_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.execution_annotations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_annotations_id_seq OWNER TO agente_user;

--
-- TOC entry 4318 (class 0 OID 0)
-- Dependencies: 385
-- Name: execution_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.execution_annotations_id_seq OWNED BY public.execution_annotations.id;


--
-- TOC entry 376 (class 1259 OID 16869)
-- Name: execution_data; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.execution_data (
    "executionId" integer NOT NULL,
    "workflowData" json NOT NULL,
    data text NOT NULL,
    "workflowVersionId" character varying(36)
);


ALTER TABLE public.execution_data OWNER TO agente_user;

--
-- TOC entry 361 (class 1259 OID 16487)
-- Name: execution_entity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.execution_entity (
    id integer NOT NULL,
    finished boolean NOT NULL,
    mode character varying NOT NULL,
    "retryOf" character varying,
    "retrySuccessId" character varying,
    "startedAt" timestamp(3) with time zone,
    "stoppedAt" timestamp(3) with time zone,
    "waitTill" timestamp(3) with time zone,
    status character varying NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "deletedAt" timestamp(3) with time zone,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "storedAt" character varying(2) DEFAULT 'db'::character varying NOT NULL,
    CONSTRAINT "execution_entity_storedAt_check" CHECK ((("storedAt")::text = ANY ((ARRAY['db'::character varying, 'fs'::character varying, 's3'::character varying])::text[])))
);


ALTER TABLE public.execution_entity OWNER TO agente_user;

--
-- TOC entry 360 (class 1259 OID 16486)
-- Name: execution_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.execution_entity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_entity_id_seq OWNER TO agente_user;

--
-- TOC entry 4319 (class 0 OID 0)
-- Dependencies: 360
-- Name: execution_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.execution_entity_id_seq OWNED BY public.execution_entity.id;


--
-- TOC entry 383 (class 1259 OID 17193)
-- Name: execution_metadata; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.execution_metadata (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    key character varying(255) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.execution_metadata OWNER TO agente_user;

--
-- TOC entry 382 (class 1259 OID 17192)
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.execution_metadata_temp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNER TO agente_user;

--
-- TOC entry 4320 (class 0 OID 0)
-- Dependencies: 382
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNED BY public.execution_metadata.id;


--
-- TOC entry 353 (class 1259 OID 16421)
-- Name: favoritos; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.favoritos (
    id integer NOT NULL,
    problematicas_id integer,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.favoritos OWNER TO agente_user;

--
-- TOC entry 352 (class 1259 OID 16420)
-- Name: favoritos_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.favoritos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.favoritos_id_seq OWNER TO agente_user;

--
-- TOC entry 4321 (class 0 OID 0)
-- Dependencies: 352
-- Name: favoritos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.favoritos_id_seq OWNED BY public.favoritos.id;


--
-- TOC entry 391 (class 1259 OID 17386)
-- Name: folder; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.folder (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "parentFolderId" character varying(36),
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.folder OWNER TO agente_user;

--
-- TOC entry 392 (class 1259 OID 17404)
-- Name: folder_tag; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.folder_tag (
    "folderId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.folder_tag OWNER TO agente_user;

--
-- TOC entry 398 (class 1259 OID 17500)
-- Name: insights_by_period; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.insights_by_period (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "periodUnit" integer NOT NULL,
    "periodStart" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.insights_by_period OWNER TO agente_user;

--
-- TOC entry 4322 (class 0 OID 0)
-- Dependencies: 398
-- Name: COLUMN insights_by_period.type; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.insights_by_period.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- TOC entry 4323 (class 0 OID 0)
-- Dependencies: 398
-- Name: COLUMN insights_by_period."periodUnit"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.insights_by_period."periodUnit" IS '0: hour, 1: day, 2: week';


--
-- TOC entry 397 (class 1259 OID 17499)
-- Name: insights_by_period_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.insights_by_period ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_by_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 394 (class 1259 OID 17471)
-- Name: insights_metadata; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.insights_metadata (
    "metaId" integer NOT NULL,
    "workflowId" character varying(36),
    "projectId" character varying(36),
    "workflowName" character varying(128) NOT NULL,
    "projectName" character varying(255) NOT NULL
);


ALTER TABLE public.insights_metadata OWNER TO agente_user;

--
-- TOC entry 393 (class 1259 OID 17470)
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.insights_metadata ALTER COLUMN "metaId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."insights_metadata_metaId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 396 (class 1259 OID 17488)
-- Name: insights_raw; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.insights_raw (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "timestamp" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.insights_raw OWNER TO agente_user;

--
-- TOC entry 4324 (class 0 OID 0)
-- Dependencies: 396
-- Name: COLUMN insights_raw.type; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.insights_raw.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- TOC entry 395 (class 1259 OID 17487)
-- Name: insights_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.insights_raw ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_raw_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 369 (class 1259 OID 16679)
-- Name: installed_nodes; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.installed_nodes (
    name character varying(200) NOT NULL,
    type character varying(200) NOT NULL,
    "latestVersion" integer DEFAULT 1 NOT NULL,
    package character varying(241) NOT NULL
);


ALTER TABLE public.installed_nodes OWNER TO agente_user;

--
-- TOC entry 368 (class 1259 OID 16672)
-- Name: installed_packages; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.installed_packages (
    "packageName" character varying(214) NOT NULL,
    "installedVersion" character varying(50) NOT NULL,
    "authorName" character varying(70),
    "authorEmail" character varying(70),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.installed_packages OWNER TO agente_user;

--
-- TOC entry 384 (class 1259 OID 17207)
-- Name: invalid_auth_token; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.invalid_auth_token (
    token character varying(512) NOT NULL,
    "expiresAt" timestamp(3) with time zone NOT NULL
);


ALTER TABLE public.invalid_auth_token OWNER TO agente_user;

--
-- TOC entry 351 (class 1259 OID 16401)
-- Name: logs_ejecucion; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.logs_ejecucion (
    id integer NOT NULL,
    flujo_nombre character varying(100) NOT NULL,
    etapa character varying(60) NOT NULL,
    estado character varying(20) NOT NULL,
    topic_id integer,
    mensaje text,
    detalles jsonb DEFAULT '{}'::jsonb,
    fecha_hora timestamp with time zone DEFAULT now(),
    CONSTRAINT logs_ejecucion_estado_check CHECK (((estado)::text = ANY ((ARRAY['inicio'::character varying, 'ok'::character varying, 'error'::character varying, 'skip'::character varying, 'en_progreso'::character varying, 'completado'::character varying])::text[])))
);


ALTER TABLE public.logs_ejecucion OWNER TO agente_user;

--
-- TOC entry 350 (class 1259 OID 16400)
-- Name: logs_ejecucion_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.logs_ejecucion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.logs_ejecucion_id_seq OWNER TO agente_user;

--
-- TOC entry 4325 (class 0 OID 0)
-- Dependencies: 350
-- Name: logs_ejecucion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.logs_ejecucion_id_seq OWNED BY public.logs_ejecucion.id;


--
-- TOC entry 358 (class 1259 OID 16468)
-- Name: migrations; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    "timestamp" bigint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.migrations OWNER TO agente_user;

--
-- TOC entry 357 (class 1259 OID 16467)
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.migrations_id_seq OWNER TO agente_user;

--
-- TOC entry 4326 (class 0 OID 0)
-- Dependencies: 357
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- TOC entry 411 (class 1259 OID 17790)
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.oauth_access_tokens (
    token character varying NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL
);


ALTER TABLE public.oauth_access_tokens OWNER TO agente_user;

--
-- TOC entry 410 (class 1259 OID 17770)
-- Name: oauth_authorization_codes; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.oauth_authorization_codes (
    code character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "redirectUri" character varying NOT NULL,
    "codeChallenge" character varying NOT NULL,
    "codeChallengeMethod" character varying(255) NOT NULL,
    "expiresAt" bigint NOT NULL,
    state character varying,
    used boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_authorization_codes OWNER TO agente_user;

--
-- TOC entry 4327 (class 0 OID 0)
-- Dependencies: 410
-- Name: COLUMN oauth_authorization_codes."expiresAt"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.oauth_authorization_codes."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- TOC entry 409 (class 1259 OID 17760)
-- Name: oauth_clients; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.oauth_clients (
    id character varying NOT NULL,
    name character varying(255) NOT NULL,
    "redirectUris" json NOT NULL,
    "grantTypes" json NOT NULL,
    "clientSecret" character varying(255),
    "clientSecretExpiresAt" bigint,
    "tokenEndpointAuthMethod" character varying(255) DEFAULT 'none'::character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_clients OWNER TO agente_user;

--
-- TOC entry 4328 (class 0 OID 0)
-- Dependencies: 409
-- Name: COLUMN oauth_clients."tokenEndpointAuthMethod"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.oauth_clients."tokenEndpointAuthMethod" IS 'Possible values: none, client_secret_basic or client_secret_post';


--
-- TOC entry 412 (class 1259 OID 17807)
-- Name: oauth_refresh_tokens; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.oauth_refresh_tokens (
    token character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "expiresAt" bigint NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_refresh_tokens OWNER TO agente_user;

--
-- TOC entry 4329 (class 0 OID 0)
-- Dependencies: 412
-- Name: COLUMN oauth_refresh_tokens."expiresAt"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.oauth_refresh_tokens."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- TOC entry 414 (class 1259 OID 17827)
-- Name: oauth_user_consents; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.oauth_user_consents (
    id integer NOT NULL,
    "userId" uuid NOT NULL,
    "clientId" character varying NOT NULL,
    "grantedAt" bigint NOT NULL
);


ALTER TABLE public.oauth_user_consents OWNER TO agente_user;

--
-- TOC entry 4330 (class 0 OID 0)
-- Dependencies: 414
-- Name: COLUMN oauth_user_consents."grantedAt"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.oauth_user_consents."grantedAt" IS 'Unix timestamp in milliseconds';


--
-- TOC entry 413 (class 1259 OID 17826)
-- Name: oauth_user_consents_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.oauth_user_consents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_user_consents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 433 (class 1259 OID 18590)
-- Name: problematicas_duplicados; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.problematicas_duplicados (
    id integer NOT NULL,
    fecha_intento timestamp without time zone DEFAULT now(),
    titulo text,
    descripcion text,
    area_social text,
    area_tecnologica text,
    solucion text,
    url_fuente text,
    motivo text DEFAULT 'URL duplicada'::text
);


ALTER TABLE public.problematicas_duplicados OWNER TO agente_user;

--
-- TOC entry 432 (class 1259 OID 18589)
-- Name: problematicas_duplicados_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.problematicas_duplicados_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.problematicas_duplicados_id_seq OWNER TO agente_user;

--
-- TOC entry 4331 (class 0 OID 0)
-- Dependencies: 432
-- Name: problematicas_duplicados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.problematicas_duplicados_id_seq OWNED BY public.problematicas_duplicados.id;


--
-- TOC entry 348 (class 1259 OID 16389)
-- Name: problematicas_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.problematicas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.problematicas_id_seq OWNER TO agente_user;

--
-- TOC entry 4332 (class 0 OID 0)
-- Dependencies: 348
-- Name: problematicas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.problematicas_id_seq OWNED BY public.problematicas.id;


--
-- TOC entry 390 (class 1259 OID 17275)
-- Name: processed_data; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.processed_data (
    "workflowId" character varying(36) NOT NULL,
    context character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.processed_data OWNER TO agente_user;

--
-- TOC entry 378 (class 1259 OID 17112)
-- Name: project; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.project (
    id character varying(36) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    description character varying(512),
    "creatorId" uuid
);


ALTER TABLE public.project OWNER TO agente_user;

--
-- TOC entry 4333 (class 0 OID 0)
-- Dependencies: 378
-- Name: COLUMN project."creatorId"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.project."creatorId" IS 'ID of the user who created the project';


--
-- TOC entry 379 (class 1259 OID 17119)
-- Name: project_relation; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.project_relation (
    "projectId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    role character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.project_relation OWNER TO agente_user;

--
-- TOC entry 425 (class 1259 OID 18057)
-- Name: project_secrets_provider_access; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.project_secrets_provider_access (
    "secretsProviderConnectionId" integer NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.project_secrets_provider_access OWNER TO agente_user;

--
-- TOC entry 402 (class 1259 OID 17556)
-- Name: role; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.role (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text,
    "roleType" text,
    "systemRole" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.role OWNER TO agente_user;

--
-- TOC entry 4334 (class 0 OID 0)
-- Dependencies: 402
-- Name: COLUMN role.slug; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.role.slug IS 'Unique identifier of the role for example: "global:owner"';


--
-- TOC entry 4335 (class 0 OID 0)
-- Dependencies: 402
-- Name: COLUMN role."displayName"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.role."displayName" IS 'Name used to display in the UI';


--
-- TOC entry 4336 (class 0 OID 0)
-- Dependencies: 402
-- Name: COLUMN role.description; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.role.description IS 'Text describing the scope in more detail of users';


--
-- TOC entry 4337 (class 0 OID 0)
-- Dependencies: 402
-- Name: COLUMN role."roleType"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.role."roleType" IS 'Type of the role, e.g., global, project, or workflow';


--
-- TOC entry 4338 (class 0 OID 0)
-- Dependencies: 402
-- Name: COLUMN role."systemRole"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.role."systemRole" IS 'Indicates if the role is managed by the system and cannot be edited';


--
-- TOC entry 403 (class 1259 OID 17564)
-- Name: role_scope; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.role_scope (
    "roleSlug" character varying(128) NOT NULL,
    "scopeSlug" character varying(128) NOT NULL
);


ALTER TABLE public.role_scope OWNER TO agente_user;

--
-- TOC entry 401 (class 1259 OID 17549)
-- Name: scope; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.scope (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text
);


ALTER TABLE public.scope OWNER TO agente_user;

--
-- TOC entry 4339 (class 0 OID 0)
-- Dependencies: 401
-- Name: COLUMN scope.slug; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.scope.slug IS 'Unique identifier of the scope for example: "project:create"';


--
-- TOC entry 4340 (class 0 OID 0)
-- Dependencies: 401
-- Name: COLUMN scope."displayName"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.scope."displayName" IS 'Name used to display in the UI';


--
-- TOC entry 4341 (class 0 OID 0)
-- Dependencies: 401
-- Name: COLUMN scope.description; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.scope.description IS 'Text describing the scope in more detail of users';


--
-- TOC entry 424 (class 1259 OID 18046)
-- Name: secrets_provider_connection; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.secrets_provider_connection (
    id integer NOT NULL,
    "providerKey" character varying(128) NOT NULL,
    type character varying(36) NOT NULL,
    "encryptedSettings" text NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.secrets_provider_connection OWNER TO agente_user;

--
-- TOC entry 4342 (class 0 OID 0)
-- Dependencies: 424
-- Name: COLUMN secrets_provider_connection.type; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.secrets_provider_connection.type IS 'Type of secrets provider. Possible values: awsSecretsManager, gcpSecretsManager, vault, azureKeyVault, infisical';


--
-- TOC entry 423 (class 1259 OID 18045)
-- Name: secrets_provider_connection_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.secrets_provider_connection ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.secrets_provider_connection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 367 (class 1259 OID 16664)
-- Name: settings; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.settings (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    "loadOnStartup" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.settings OWNER TO agente_user;

--
-- TOC entry 380 (class 1259 OID 17147)
-- Name: shared_credentials; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.shared_credentials (
    "credentialsId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_credentials OWNER TO agente_user;

--
-- TOC entry 381 (class 1259 OID 17173)
-- Name: shared_workflow; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.shared_workflow (
    "workflowId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_workflow OWNER TO agente_user;

--
-- TOC entry 364 (class 1259 OID 16515)
-- Name: tag_entity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.tag_entity (
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL
);


ALTER TABLE public.tag_entity OWNER TO agente_user;

--
-- TOC entry 400 (class 1259 OID 17527)
-- Name: test_case_execution; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.test_case_execution (
    id character varying(36) NOT NULL,
    "testRunId" character varying(36) NOT NULL,
    "executionId" integer,
    status character varying NOT NULL,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    "errorCode" character varying,
    "errorDetails" json,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    inputs json,
    outputs json
);


ALTER TABLE public.test_case_execution OWNER TO agente_user;

--
-- TOC entry 399 (class 1259 OID 17512)
-- Name: test_run; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.test_run (
    id character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    status character varying NOT NULL,
    "errorCode" character varying,
    "errorDetails" json,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "runningInstanceId" character varying(255),
    "cancelRequested" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.test_run OWNER TO agente_user;

--
-- TOC entry 366 (class 1259 OID 16601)
-- Name: user; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public."user" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255),
    "firstName" character varying(32),
    "lastName" character varying(32),
    password character varying(255),
    "personalizationAnswers" json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    disabled boolean DEFAULT false NOT NULL,
    "mfaEnabled" boolean DEFAULT false NOT NULL,
    "mfaSecret" text,
    "mfaRecoveryCodes" text,
    "lastActiveAt" date,
    "roleSlug" character varying(128) DEFAULT 'global:member'::character varying NOT NULL
);


ALTER TABLE public."user" OWNER TO agente_user;

--
-- TOC entry 389 (class 1259 OID 17259)
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.user_api_keys (
    id character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    label character varying(100) NOT NULL,
    "apiKey" character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    scopes json,
    audience character varying DEFAULT 'public-api'::character varying NOT NULL
);


ALTER TABLE public.user_api_keys OWNER TO agente_user;

--
-- TOC entry 375 (class 1259 OID 16785)
-- Name: variables; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.variables (
    key character varying(50) NOT NULL,
    type character varying(50) DEFAULT 'string'::character varying NOT NULL,
    value character varying(255),
    id character varying(36) NOT NULL,
    "projectId" character varying(36)
);


ALTER TABLE public.variables OWNER TO agente_user;

--
-- TOC entry 363 (class 1259 OID 16505)
-- Name: webhook_entity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.webhook_entity (
    "webhookPath" character varying NOT NULL,
    method character varying NOT NULL,
    node character varying NOT NULL,
    "webhookId" character varying,
    "pathLength" integer,
    "workflowId" character varying(36) NOT NULL
);


ALTER TABLE public.webhook_entity OWNER TO agente_user;

--
-- TOC entry 431 (class 1259 OID 18160)
-- Name: workflow_builder_session; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_builder_session (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    messages json DEFAULT '[]'::json NOT NULL,
    "previousSummary" text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.workflow_builder_session OWNER TO agente_user;

--
-- TOC entry 4343 (class 0 OID 0)
-- Dependencies: 431
-- Name: COLUMN workflow_builder_session."previousSummary"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_builder_session."previousSummary" IS 'Summary of prior conversation from compaction (/compact or auto-compact)';


--
-- TOC entry 416 (class 1259 OID 17847)
-- Name: workflow_dependency; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_dependency (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "workflowVersionId" integer NOT NULL,
    "dependencyType" character varying(32) NOT NULL,
    "dependencyKey" character varying(255) NOT NULL,
    "dependencyInfo" json,
    "indexVersionId" smallint DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "publishedVersionId" character varying(36)
);


ALTER TABLE public.workflow_dependency OWNER TO agente_user;

--
-- TOC entry 4344 (class 0 OID 0)
-- Dependencies: 416
-- Name: COLUMN workflow_dependency."workflowVersionId"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_dependency."workflowVersionId" IS 'Version of the workflow';


--
-- TOC entry 4345 (class 0 OID 0)
-- Dependencies: 416
-- Name: COLUMN workflow_dependency."dependencyType"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_dependency."dependencyType" IS 'Type of dependency: "credential", "nodeType", "webhookPath", or "workflowCall"';


--
-- TOC entry 4346 (class 0 OID 0)
-- Dependencies: 416
-- Name: COLUMN workflow_dependency."dependencyKey"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_dependency."dependencyKey" IS 'ID or name of the dependency';


--
-- TOC entry 4347 (class 0 OID 0)
-- Dependencies: 416
-- Name: COLUMN workflow_dependency."dependencyInfo"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_dependency."dependencyInfo" IS 'Additional info about the dependency, interpreted based on type';


--
-- TOC entry 4348 (class 0 OID 0)
-- Dependencies: 416
-- Name: COLUMN workflow_dependency."indexVersionId"; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_dependency."indexVersionId" IS 'Version of the index structure';


--
-- TOC entry 415 (class 1259 OID 17846)
-- Name: workflow_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.workflow_dependency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 362 (class 1259 OID 16497)
-- Name: workflow_entity; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_entity (
    name character varying(128) NOT NULL,
    active boolean NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    "staticData" json,
    "pinData" json,
    "versionId" character(36) NOT NULL,
    "triggerCount" integer DEFAULT 0 NOT NULL,
    id character varying(36) NOT NULL,
    meta json,
    "parentFolderId" character varying(36) DEFAULT NULL::character varying,
    "isArchived" boolean DEFAULT false NOT NULL,
    "versionCounter" integer DEFAULT 1 NOT NULL,
    description text,
    "activeVersionId" character varying(36)
);


ALTER TABLE public.workflow_entity OWNER TO agente_user;

--
-- TOC entry 377 (class 1259 OID 16883)
-- Name: workflow_history; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_history (
    "versionId" character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    authors character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    name character varying(128),
    autosaved boolean DEFAULT false NOT NULL,
    description text
);


ALTER TABLE public.workflow_history OWNER TO agente_user;

--
-- TOC entry 419 (class 1259 OID 17899)
-- Name: workflow_publish_history; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_publish_history (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "versionId" character varying(36) NOT NULL,
    event character varying(36) NOT NULL,
    "userId" uuid,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_workflow_publish_history_event" CHECK (((event)::text = ANY ((ARRAY['activated'::character varying, 'deactivated'::character varying])::text[])))
);


ALTER TABLE public.workflow_publish_history OWNER TO agente_user;

--
-- TOC entry 4349 (class 0 OID 0)
-- Dependencies: 419
-- Name: COLUMN workflow_publish_history.event; Type: COMMENT; Schema: public; Owner: agente_user
--

COMMENT ON COLUMN public.workflow_publish_history.event IS 'Type of history record: activated (workflow is now active), deactivated (workflow is now inactive)';


--
-- TOC entry 418 (class 1259 OID 17898)
-- Name: workflow_publish_history_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

ALTER TABLE public.workflow_publish_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_publish_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 426 (class 1259 OID 18074)
-- Name: workflow_published_version; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_published_version (
    "workflowId" character varying(36) NOT NULL,
    "publishedVersionId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.workflow_published_version OWNER TO agente_user;

--
-- TOC entry 370 (class 1259 OID 16700)
-- Name: workflow_statistics; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflow_statistics (
    count bigint DEFAULT 0,
    "latestEvent" timestamp(3) with time zone,
    name character varying(128) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "rootCount" bigint DEFAULT 0,
    id integer NOT NULL,
    "workflowName" character varying(128)
);


ALTER TABLE public.workflow_statistics OWNER TO agente_user;

--
-- TOC entry 421 (class 1259 OID 17995)
-- Name: workflow_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: agente_user
--

CREATE SEQUENCE public.workflow_statistics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.workflow_statistics_id_seq OWNER TO agente_user;

--
-- TOC entry 4350 (class 0 OID 0)
-- Dependencies: 421
-- Name: workflow_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: agente_user
--

ALTER SEQUENCE public.workflow_statistics_id_seq OWNED BY public.workflow_statistics.id;


--
-- TOC entry 365 (class 1259 OID 16522)
-- Name: workflows_tags; Type: TABLE; Schema: public; Owner: agente_user
--

CREATE TABLE public.workflows_tags (
    "workflowId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.workflows_tags OWNER TO agente_user;

--
-- TOC entry 3722 (class 2604 OID 16446)
-- Name: auditoria_problematicas id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.auditoria_problematicas ALTER COLUMN id SET DEFAULT nextval('public.auditoria_problematicas_id_seq'::regclass);


--
-- TOC entry 3759 (class 2604 OID 16777)
-- Name: auth_provider_sync_history id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.auth_provider_sync_history ALTER COLUMN id SET DEFAULT nextval('public.auth_provider_sync_history_id_seq'::regclass);


--
-- TOC entry 3844 (class 2604 OID 18779)
-- Name: catalogo_area_social id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.catalogo_area_social ALTER COLUMN id SET DEFAULT nextval('public.catalogo_area_social_id_seq'::regclass);


--
-- TOC entry 3845 (class 2604 OID 18788)
-- Name: catalogo_area_tecnologica id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.catalogo_area_tecnologica ALTER COLUMN id SET DEFAULT nextval('public.catalogo_area_tecnologica_id_seq'::regclass);


--
-- TOC entry 3775 (class 2604 OID 17221)
-- Name: execution_annotations id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_annotations ALTER COLUMN id SET DEFAULT nextval('public.execution_annotations_id_seq'::regclass);


--
-- TOC entry 3731 (class 2604 OID 16490)
-- Name: execution_entity id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_entity ALTER COLUMN id SET DEFAULT nextval('public.execution_entity_id_seq'::regclass);


--
-- TOC entry 3774 (class 2604 OID 17196)
-- Name: execution_metadata id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_metadata ALTER COLUMN id SET DEFAULT nextval('public.execution_metadata_temp_id_seq'::regclass);


--
-- TOC entry 3720 (class 2604 OID 16424)
-- Name: favoritos id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.favoritos ALTER COLUMN id SET DEFAULT nextval('public.favoritos_id_seq'::regclass);


--
-- TOC entry 3717 (class 2604 OID 16404)
-- Name: logs_ejecucion id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.logs_ejecucion ALTER COLUMN id SET DEFAULT nextval('public.logs_ejecucion_id_seq'::regclass);


--
-- TOC entry 3724 (class 2604 OID 16471)
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- TOC entry 3715 (class 2604 OID 16393)
-- Name: problematicas id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.problematicas ALTER COLUMN id SET DEFAULT nextval('public.problematicas_id_seq'::regclass);


--
-- TOC entry 3841 (class 2604 OID 18593)
-- Name: problematicas_duplicados id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.problematicas_duplicados ALTER COLUMN id SET DEFAULT nextval('public.problematicas_duplicados_id_seq'::regclass);


--
-- TOC entry 3754 (class 2604 OID 17996)
-- Name: workflow_statistics id; Type: DEFAULT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_statistics ALTER COLUMN id SET DEFAULT nextval('public.workflow_statistics_id_seq'::regclass);


--
-- TOC entry 3963 (class 2606 OID 17520)
-- Name: test_run PK_011c050f566e9db509a0fadb9b9; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "PK_011c050f566e9db509a0fadb9b9" PRIMARY KEY (id);


--
-- TOC entry 4026 (class 2606 OID 18063)
-- Name: project_secrets_provider_access PK_0402b7fcec5415246656f102f83; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "PK_0402b7fcec5415246656f102f83" PRIMARY KEY ("secretsProviderConnectionId", "projectId");


--
-- TOC entry 3894 (class 2606 OID 16678)
-- Name: installed_packages PK_08cc9197c39b028c1e9beca225940576fd1a5804; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.installed_packages
    ADD CONSTRAINT "PK_08cc9197c39b028c1e9beca225940576fd1a5804" PRIMARY KEY ("packageName");


--
-- TOC entry 3929 (class 2606 OID 17200)
-- Name: execution_metadata PK_17a0b6284f8d626aae88e1c16e4; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "PK_17a0b6284f8d626aae88e1c16e4" PRIMARY KEY (id);


--
-- TOC entry 3920 (class 2606 OID 17127)
-- Name: project_relation PK_1caaa312a5d7184a003be0f0cb6; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "PK_1caaa312a5d7184a003be0f0cb6" PRIMARY KEY ("projectId", "userId");


--
-- TOC entry 3985 (class 2606 OID 17676)
-- Name: chat_hub_sessions PK_1eafef1273c70e4464fec703412; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "PK_1eafef1273c70e4464fec703412" PRIMARY KEY (id);


--
-- TOC entry 3952 (class 2606 OID 17408)
-- Name: folder_tag PK_27e4e00852f6b06a925a4d83a3e; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "PK_27e4e00852f6b06a925a4d83a3e" PRIMARY KEY ("folderId", "tagId");


--
-- TOC entry 3971 (class 2606 OID 17563)
-- Name: role PK_35c9b140caaf6da09cfabb0d675; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT "PK_35c9b140caaf6da09cfabb0d675" PRIMARY KEY (slug);


--
-- TOC entry 4024 (class 2606 OID 18055)
-- Name: secrets_provider_connection PK_4350ae85e76f9ba7df1370acb5d; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.secrets_provider_connection
    ADD CONSTRAINT "PK_4350ae85e76f9ba7df1370acb5d" PRIMARY KEY (id);


--
-- TOC entry 3916 (class 2606 OID 17118)
-- Name: project PK_4d68b1358bb5b766d3e78f32f57; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "PK_4d68b1358bb5b766d3e78f32f57" PRIMARY KEY (id);


--
-- TOC entry 4032 (class 2606 OID 18099)
-- Name: dynamic_credential_entry PK_5135ffcabecad4727ff6b9b803d; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "PK_5135ffcabecad4727ff6b9b803d" PRIMARY KEY (credential_id, subject_id, resolver_id);


--
-- TOC entry 4008 (class 2606 OID 17855)
-- Name: workflow_dependency PK_52325e34cd7a2f0f67b0f3cad65; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "PK_52325e34cd7a2f0f67b0f3cad65" PRIMARY KEY (id);


--
-- TOC entry 3931 (class 2606 OID 17213)
-- Name: invalid_auth_token PK_5779069b7235b256d91f7af1a15; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.invalid_auth_token
    ADD CONSTRAINT "PK_5779069b7235b256d91f7af1a15" PRIMARY KEY (token);


--
-- TOC entry 3926 (class 2606 OID 17181)
-- Name: shared_workflow PK_5ba87620386b847201c9531c58f; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "PK_5ba87620386b847201c9531c58f" PRIMARY KEY ("workflowId", "projectId");


--
-- TOC entry 4028 (class 2606 OID 18080)
-- Name: workflow_published_version PK_5c76fb7ee939fe2530374d3f75a; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "PK_5c76fb7ee939fe2530374d3f75a" PRIMARY KEY ("workflowId");


--
-- TOC entry 3950 (class 2606 OID 17392)
-- Name: folder PK_6278a41a706740c94c02e288df8; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "PK_6278a41a706740c94c02e288df8" PRIMARY KEY (id);


--
-- TOC entry 3980 (class 2606 OID 17640)
-- Name: data_table_column PK_673cb121ee4a8a5e27850c72c51; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "PK_673cb121ee4a8a5e27850c72c51" PRIMARY KEY (id);


--
-- TOC entry 4035 (class 2606 OID 18121)
-- Name: chat_hub_tools PK_696d26426c704fba79b2c195ef5; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_tools
    ADD CONSTRAINT "PK_696d26426c704fba79b2c195ef5" PRIMARY KEY (id);


--
-- TOC entry 3937 (class 2606 OID 17240)
-- Name: annotation_tag_entity PK_69dfa041592c30bbc0d4b84aa00; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.annotation_tag_entity
    ADD CONSTRAINT "PK_69dfa041592c30bbc0d4b84aa00" PRIMARY KEY (id);


--
-- TOC entry 3998 (class 2606 OID 17815)
-- Name: oauth_refresh_tokens PK_74abaed0b30711b6532598b0392; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "PK_74abaed0b30711b6532598b0392" PRIMARY KEY (token);


--
-- TOC entry 4021 (class 2606 OID 18026)
-- Name: dynamic_credential_user_entry PK_74f548e633abc66dc27c8f0ca77; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "PK_74f548e633abc66dc27c8f0ca77" PRIMARY KEY ("credentialId", "userId", "resolverId");


--
-- TOC entry 3988 (class 2606 OID 17702)
-- Name: chat_hub_messages PK_7704a5add6baed43eef835f0bfb; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "PK_7704a5add6baed43eef835f0bfb" PRIMARY KEY (id);


--
-- TOC entry 3934 (class 2606 OID 17227)
-- Name: execution_annotations PK_7afcf93ffa20c4252869a7c6a23; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "PK_7afcf93ffa20c4252869a7c6a23" PRIMARY KEY (id);


--
-- TOC entry 4000 (class 2606 OID 17833)
-- Name: oauth_user_consents PK_85b9ada746802c8993103470f05; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "PK_85b9ada746802c8993103470f05" PRIMARY KEY (id);


--
-- TOC entry 4037 (class 2606 OID 18132)
-- Name: chat_hub_session_tools PK_87aea76ff4c274c4a5ac838ebe3; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "PK_87aea76ff4c274c4a5ac838ebe3" PRIMARY KEY ("sessionId", "toolId");


--
-- TOC entry 3861 (class 2606 OID 16475)
-- Name: migrations PK_8c82d7f526340ab734260ea46be; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT "PK_8c82d7f526340ab734260ea46be" PRIMARY KEY (id);


--
-- TOC entry 3896 (class 2606 OID 16686)
-- Name: installed_nodes PK_8ebd28194e4f792f96b5933423fc439df97d9689; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "PK_8ebd28194e4f792f96b5933423fc439df97d9689" PRIMARY KEY (name);


--
-- TOC entry 3924 (class 2606 OID 17155)
-- Name: shared_credentials PK_8ef3a59796a228913f251779cff; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "PK_8ef3a59796a228913f251779cff" PRIMARY KEY ("credentialsId", "projectId");


--
-- TOC entry 3966 (class 2606 OID 17535)
-- Name: test_case_execution PK_90c121f77a78a6580e94b794bce; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "PK_90c121f77a78a6580e94b794bce" PRIMARY KEY (id);


--
-- TOC entry 3945 (class 2606 OID 17267)
-- Name: user_api_keys PK_978fa5caa3468f463dac9d92e69; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "PK_978fa5caa3468f463dac9d92e69" PRIMARY KEY (id);


--
-- TOC entry 3941 (class 2606 OID 17246)
-- Name: execution_annotation_tags PK_979ec03d31294cca484be65d11f; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "PK_979ec03d31294cca484be65d11f" PRIMARY KEY ("annotationId", "tagId");


--
-- TOC entry 3877 (class 2606 OID 16511)
-- Name: webhook_entity PK_b21ace2e13596ccd87dc9bf4ea6; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT "PK_b21ace2e13596ccd87dc9bf4ea6" PRIMARY KEY ("webhookPath", method);


--
-- TOC entry 3960 (class 2606 OID 17505)
-- Name: insights_by_period PK_b606942249b90cc39b0265f0575; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "PK_b606942249b90cc39b0265f0575" PRIMARY KEY (id);


--
-- TOC entry 3914 (class 2606 OID 16891)
-- Name: workflow_history PK_b6572dd6173e4cd06fe79937b58; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "PK_b6572dd6173e4cd06fe79937b58" PRIMARY KEY ("versionId");


--
-- TOC entry 4017 (class 2606 OID 17935)
-- Name: dynamic_credential_resolver PK_b76cfb088dcdaf5275e9980bb64; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_resolver
    ADD CONSTRAINT "PK_b76cfb088dcdaf5275e9980bb64" PRIMARY KEY (id);


--
-- TOC entry 3968 (class 2606 OID 17555)
-- Name: scope PK_bfc45df0481abd7f355d6187da1; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.scope
    ADD CONSTRAINT "PK_bfc45df0481abd7f355d6187da1" PRIMARY KEY (slug);


--
-- TOC entry 3992 (class 2606 OID 17769)
-- Name: oauth_clients PK_c4759172d3431bae6f04e678e0d; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_clients
    ADD CONSTRAINT "PK_c4759172d3431bae6f04e678e0d" PRIMARY KEY (id);


--
-- TOC entry 4014 (class 2606 OID 17905)
-- Name: workflow_publish_history PK_c788f7caf88e91e365c97d6d04a; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "PK_c788f7caf88e91e365c97d6d04a" PRIMARY KEY (id);


--
-- TOC entry 3947 (class 2606 OID 17283)
-- Name: processed_data PK_ca04b9d8dc72de268fe07a65773; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "PK_ca04b9d8dc72de268fe07a65773" PRIMARY KEY ("workflowId", context);


--
-- TOC entry 4039 (class 2606 OID 18147)
-- Name: chat_hub_agent_tools PK_cc8806fdea48297a7d497035d72; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "PK_cc8806fdea48297a7d497035d72" PRIMARY KEY ("agentId", "toolId");


--
-- TOC entry 3892 (class 2606 OID 16671)
-- Name: settings PK_dc0fe14e6d9943f268e7b119f69ab8bd; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT "PK_dc0fe14e6d9943f268e7b119f69ab8bd" PRIMARY KEY (key);


--
-- TOC entry 3996 (class 2606 OID 17796)
-- Name: oauth_access_tokens PK_dcd71f96a5d5f4bf79e67d322bf; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "PK_dcd71f96a5d5f4bf79e67d322bf" PRIMARY KEY (token);


--
-- TOC entry 3976 (class 2606 OID 17626)
-- Name: data_table PK_e226d0001b9e6097cbfe70617cb; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "PK_e226d0001b9e6097cbfe70617cb" PRIMARY KEY (id);


--
-- TOC entry 4041 (class 2606 OID 18170)
-- Name: workflow_builder_session PK_e69ef0d385986e273423b0e8695; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "PK_e69ef0d385986e273423b0e8695" PRIMARY KEY (id);


--
-- TOC entry 3887 (class 2606 OID 16610)
-- Name: user PK_ea8f538c94b6e352418254ed6474a81f; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "PK_ea8f538c94b6e352418254ed6474a81f" PRIMARY KEY (id);


--
-- TOC entry 3957 (class 2606 OID 17493)
-- Name: insights_raw PK_ec15125755151e3a7e00e00014f; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "PK_ec15125755151e3a7e00e00014f" PRIMARY KEY (id);


--
-- TOC entry 3990 (class 2606 OID 17746)
-- Name: chat_hub_agents PK_f39a3b36bbdf0e2979ddb21cf78; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "PK_f39a3b36bbdf0e2979ddb21cf78" PRIMARY KEY (id);


--
-- TOC entry 3955 (class 2606 OID 17475)
-- Name: insights_metadata PK_f448a94c35218b6208ce20cf5a1; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "PK_f448a94c35218b6208ce20cf5a1" PRIMARY KEY ("metaId");


--
-- TOC entry 3994 (class 2606 OID 17779)
-- Name: oauth_authorization_codes PK_fb91ab932cfbd694061501cc20f; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "PK_fb91ab932cfbd694061501cc20f" PRIMARY KEY (code);


--
-- TOC entry 4011 (class 2606 OID 17896)
-- Name: binary_data PK_fc3691585b39408bb0551122af6; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.binary_data
    ADD CONSTRAINT "PK_fc3691585b39408bb0551122af6" PRIMARY KEY ("fileId");


--
-- TOC entry 3974 (class 2606 OID 17568)
-- Name: role_scope PK_role_scope; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "PK_role_scope" PRIMARY KEY ("roleSlug", "scopeSlug");


--
-- TOC entry 4002 (class 2606 OID 17835)
-- Name: oauth_user_consents UQ_083721d99ce8db4033e2958ebb4; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "UQ_083721d99ce8db4033e2958ebb4" UNIQUE ("userId", "clientId");


--
-- TOC entry 3982 (class 2606 OID 17642)
-- Name: data_table_column UQ_8082ec4890f892f0bc77473a123; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "UQ_8082ec4890f892f0bc77473a123" UNIQUE ("dataTableId", name);


--
-- TOC entry 3978 (class 2606 OID 17628)
-- Name: data_table UQ_b23096ef747281ac944d28e8b0d; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "UQ_b23096ef747281ac944d28e8b0d" UNIQUE ("projectId", name);


--
-- TOC entry 3889 (class 2606 OID 16612)
-- Name: user UQ_e12875dfb3b1d92d7d7c5377e2; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "UQ_e12875dfb3b1d92d7d7c5377e2" UNIQUE (email);


--
-- TOC entry 4043 (class 2606 OID 18172)
-- Name: workflow_builder_session UQ_ec2aa73632932d485a1d5192ce1; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "UQ_ec2aa73632932d485a1d5192ce1" UNIQUE ("workflowId", "userId");


--
-- TOC entry 3859 (class 2606 OID 16451)
-- Name: auditoria_problematicas auditoria_problematicas_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.auditoria_problematicas
    ADD CONSTRAINT auditoria_problematicas_pkey PRIMARY KEY (id);


--
-- TOC entry 3903 (class 2606 OID 18159)
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY ("providerId", "providerType");


--
-- TOC entry 3905 (class 2606 OID 16783)
-- Name: auth_provider_sync_history auth_provider_sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.auth_provider_sync_history
    ADD CONSTRAINT auth_provider_sync_history_pkey PRIMARY KEY (id);


--
-- TOC entry 4047 (class 2606 OID 18783)
-- Name: catalogo_area_social catalogo_area_social_nombre_key; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.catalogo_area_social
    ADD CONSTRAINT catalogo_area_social_nombre_key UNIQUE (nombre);


--
-- TOC entry 4049 (class 2606 OID 18781)
-- Name: catalogo_area_social catalogo_area_social_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.catalogo_area_social
    ADD CONSTRAINT catalogo_area_social_pkey PRIMARY KEY (id);


--
-- TOC entry 4051 (class 2606 OID 18792)
-- Name: catalogo_area_tecnologica catalogo_area_tecnologica_nombre_key; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.catalogo_area_tecnologica
    ADD CONSTRAINT catalogo_area_tecnologica_nombre_key UNIQUE (nombre);


--
-- TOC entry 4053 (class 2606 OID 18790)
-- Name: catalogo_area_tecnologica catalogo_area_tecnologica_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.catalogo_area_tecnologica
    ADD CONSTRAINT catalogo_area_tecnologica_pkey PRIMARY KEY (id);


--
-- TOC entry 3863 (class 2606 OID 16865)
-- Name: credentials_entity credentials_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT credentials_entity_pkey PRIMARY KEY (id);


--
-- TOC entry 3901 (class 2606 OID 16738)
-- Name: event_destinations event_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.event_destinations
    ADD CONSTRAINT event_destinations_pkey PRIMARY KEY (id);


--
-- TOC entry 3911 (class 2606 OID 16881)
-- Name: execution_data execution_data_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_pkey PRIMARY KEY ("executionId");


--
-- TOC entry 3857 (class 2606 OID 16427)
-- Name: favoritos favoritos_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_pkey PRIMARY KEY (id);


--
-- TOC entry 3855 (class 2606 OID 16411)
-- Name: logs_ejecucion logs_ejecucion_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.logs_ejecucion
    ADD CONSTRAINT logs_ejecucion_pkey PRIMARY KEY (id);


--
-- TOC entry 3871 (class 2606 OID 16494)
-- Name: execution_entity pk_e3e63bbf986767844bbe1166d4e; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT pk_e3e63bbf986767844bbe1166d4e PRIMARY KEY (id);


--
-- TOC entry 3885 (class 2606 OID 16813)
-- Name: workflows_tags pk_workflows_tags; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT pk_workflows_tags PRIMARY KEY ("workflowId", "tagId");


--
-- TOC entry 4045 (class 2606 OID 18599)
-- Name: problematicas_duplicados problematicas_duplicados_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.problematicas_duplicados
    ADD CONSTRAINT problematicas_duplicados_pkey PRIMARY KEY (id);


--
-- TOC entry 3851 (class 2606 OID 16398)
-- Name: problematicas problematicas_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.problematicas
    ADD CONSTRAINT problematicas_pkey PRIMARY KEY (id);


--
-- TOC entry 3882 (class 2606 OID 16854)
-- Name: tag_entity tag_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.tag_entity
    ADD CONSTRAINT tag_entity_pkey PRIMARY KEY (id);


--
-- TOC entry 3853 (class 2606 OID 16419)
-- Name: problematicas unique_url; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.problematicas
    ADD CONSTRAINT unique_url UNIQUE (url_fuente);


--
-- TOC entry 3908 (class 2606 OID 16868)
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- TOC entry 3875 (class 2606 OID 16852)
-- Name: workflow_entity workflow_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT workflow_entity_pkey PRIMARY KEY (id);


--
-- TOC entry 3899 (class 2606 OID 17998)
-- Name: workflow_statistics workflow_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT workflow_statistics_pkey PRIMARY KEY (id);


--
-- TOC entry 4012 (class 1259 OID 17921)
-- Name: IDX_070b5de842ece9ccdda0d9738b; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_070b5de842ece9ccdda0d9738b" ON public.workflow_publish_history USING btree ("workflowId", "versionId");


--
-- TOC entry 3948 (class 1259 OID 17403)
-- Name: IDX_14f68deffaf858465715995508; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_14f68deffaf858465715995508" ON public.folder USING btree ("projectId", id);


--
-- TOC entry 3953 (class 1259 OID 17989)
-- Name: IDX_1d8ab99d5861c9388d2dc1cf73; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_1d8ab99d5861c9388d2dc1cf73" ON public.insights_metadata USING btree ("workflowId");


--
-- TOC entry 3912 (class 1259 OID 16897)
-- Name: IDX_1e31657f5fe46816c34be7c1b4; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_1e31657f5fe46816c34be7c1b4" ON public.workflow_history USING btree ("workflowId");


--
-- TOC entry 3942 (class 1259 OID 17274)
-- Name: IDX_1ef35bac35d20bdae979d917a3; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_1ef35bac35d20bdae979d917a3" ON public.user_api_keys USING btree ("apiKey");


--
-- TOC entry 4033 (class 1259 OID 18127)
-- Name: IDX_4c72ebdb265d1775bf61147af0; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_4c72ebdb265d1775bf61147af0" ON public.chat_hub_tools USING btree ("ownerId", name);


--
-- TOC entry 4009 (class 1259 OID 17897)
-- Name: IDX_56900edc3cfd16612e2ef2c6a8; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_56900edc3cfd16612e2ef2c6a8" ON public.binary_data USING btree ("sourceType", "sourceId");


--
-- TOC entry 3917 (class 1259 OID 17139)
-- Name: IDX_5f0643f6717905a05164090dde; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_5f0643f6717905a05164090dde" ON public.project_relation USING btree ("userId");


--
-- TOC entry 3958 (class 1259 OID 17511)
-- Name: IDX_60b6a84299eeb3f671dfec7693; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_60b6a84299eeb3f671dfec7693" ON public.insights_by_period USING btree ("periodStart", type, "periodUnit", "metaId");


--
-- TOC entry 3918 (class 1259 OID 17138)
-- Name: IDX_61448d56d61802b5dfde5cdb00; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_61448d56d61802b5dfde5cdb00" ON public.project_relation USING btree ("projectId");


--
-- TOC entry 4029 (class 1259 OID 18110)
-- Name: IDX_62476b94b56d9dc7ed9ed75d3d; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_62476b94b56d9dc7ed9ed75d3d" ON public.dynamic_credential_entry USING btree (subject_id);


--
-- TOC entry 3943 (class 1259 OID 17273)
-- Name: IDX_63d7bbae72c767cf162d459fcc; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_63d7bbae72c767cf162d459fcc" ON public.user_api_keys USING btree ("userId", label);


--
-- TOC entry 4018 (class 1259 OID 18043)
-- Name: IDX_6edec973a6450990977bb854c3; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_6edec973a6450990977bb854c3" ON public.dynamic_credential_user_entry USING btree ("resolverId");


--
-- TOC entry 3964 (class 1259 OID 17546)
-- Name: IDX_8e4b4774db42f1e6dda3452b2a; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_8e4b4774db42f1e6dda3452b2a" ON public.test_case_execution USING btree ("testRunId");


--
-- TOC entry 3932 (class 1259 OID 17233)
-- Name: IDX_97f863fa83c4786f1956508496; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_97f863fa83c4786f1956508496" ON public.execution_annotations USING btree ("executionId");


--
-- TOC entry 4015 (class 1259 OID 17936)
-- Name: IDX_9c9ee9df586e60bb723234e499; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_9c9ee9df586e60bb723234e499" ON public.dynamic_credential_resolver USING btree (type);


--
-- TOC entry 3969 (class 1259 OID 17759)
-- Name: IDX_UniqueRoleDisplayName; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_UniqueRoleDisplayName" ON public.role USING btree ("displayName");


--
-- TOC entry 3938 (class 1259 OID 17257)
-- Name: IDX_a3697779b366e131b2bbdae297; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_a3697779b366e131b2bbdae297" ON public.execution_annotation_tags USING btree ("tagId");


--
-- TOC entry 4019 (class 1259 OID 18042)
-- Name: IDX_a36dc616fabc3f736bb82410a2; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_a36dc616fabc3f736bb82410a2" ON public.dynamic_credential_user_entry USING btree ("userId");


--
-- TOC entry 4003 (class 1259 OID 17861)
-- Name: IDX_a4ff2d9b9628ea988fa9e7d0bf; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_a4ff2d9b9628ea988fa9e7d0bf" ON public.workflow_dependency USING btree ("workflowId");


--
-- TOC entry 3935 (class 1259 OID 17241)
-- Name: IDX_ae51b54c4bb430cf92f48b623f; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_ae51b54c4bb430cf92f48b623f" ON public.annotation_tag_entity USING btree (name);


--
-- TOC entry 3939 (class 1259 OID 17258)
-- Name: IDX_c1519757391996eb06064f0e7c; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_c1519757391996eb06064f0e7c" ON public.execution_annotation_tags USING btree ("annotationId");


--
-- TOC entry 3927 (class 1259 OID 17206)
-- Name: IDX_cec8eea3bf49551482ccb4933e; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_cec8eea3bf49551482ccb4933e" ON public.execution_metadata USING btree ("executionId", key);


--
-- TOC entry 3986 (class 1259 OID 17988)
-- Name: IDX_chat_hub_messages_sessionId; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_chat_hub_messages_sessionId" ON public.chat_hub_messages USING btree ("sessionId");


--
-- TOC entry 3983 (class 1259 OID 17987)
-- Name: IDX_chat_hub_sessions_owner_lastmsg_id; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_chat_hub_sessions_owner_lastmsg_id" ON public.chat_hub_sessions USING btree ("ownerId", "lastMessageAt" DESC, id);


--
-- TOC entry 4030 (class 1259 OID 18111)
-- Name: IDX_d61a12235d268a49af6a3c09c1; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_d61a12235d268a49af6a3c09c1" ON public.dynamic_credential_entry USING btree (resolver_id);


--
-- TOC entry 3961 (class 1259 OID 17526)
-- Name: IDX_d6870d3b6e4c185d33926f423c; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_d6870d3b6e4c185d33926f423c" ON public.test_run USING btree ("workflowId");


--
-- TOC entry 4004 (class 1259 OID 17863)
-- Name: IDX_e48a201071ab85d9d09119d640; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_e48a201071ab85d9d09119d640" ON public.workflow_dependency USING btree ("dependencyKey");


--
-- TOC entry 4005 (class 1259 OID 17862)
-- Name: IDX_e7fe1cfda990c14a445937d0b9; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_e7fe1cfda990c14a445937d0b9" ON public.workflow_dependency USING btree ("dependencyType");


--
-- TOC entry 3866 (class 1259 OID 16898)
-- Name: IDX_execution_entity_deletedAt; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_execution_entity_deletedAt" ON public.execution_entity USING btree ("deletedAt");


--
-- TOC entry 3972 (class 1259 OID 17579)
-- Name: IDX_role_scope_scopeSlug; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_role_scope_scopeSlug" ON public.role_scope USING btree ("scopeSlug");


--
-- TOC entry 4022 (class 1259 OID 18056)
-- Name: IDX_secrets_provider_connection_providerKey; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_secrets_provider_connection_providerKey" ON public.secrets_provider_connection USING btree ("providerKey");


--
-- TOC entry 4006 (class 1259 OID 18044)
-- Name: IDX_workflow_dependency_publishedVersionId; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_workflow_dependency_publishedVersionId" ON public.workflow_dependency USING btree ("publishedVersionId");


--
-- TOC entry 3872 (class 1259 OID 16882)
-- Name: IDX_workflow_entity_name; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX "IDX_workflow_entity_name" ON public.workflow_entity USING btree (name);


--
-- TOC entry 3897 (class 1259 OID 18003)
-- Name: IDX_workflow_statistics_workflow_name; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX "IDX_workflow_statistics_workflow_name" ON public.workflow_statistics USING btree ("workflowId", name);


--
-- TOC entry 3864 (class 1259 OID 16589)
-- Name: idx_07fde106c0b471d8cc80a64fc8; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX idx_07fde106c0b471d8cc80a64fc8 ON public.credentials_entity USING btree (type);


--
-- TOC entry 3878 (class 1259 OID 16513)
-- Name: idx_16f4436789e804e3e1c9eeb240; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX idx_16f4436789e804e3e1c9eeb240 ON public.webhook_entity USING btree ("webhookId", method, "pathLength");


--
-- TOC entry 3879 (class 1259 OID 16521)
-- Name: idx_812eb05f7451ca757fb98444ce; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX idx_812eb05f7451ca757fb98444ce ON public.tag_entity USING btree (name);


--
-- TOC entry 3867 (class 1259 OID 17216)
-- Name: idx_execution_entity_stopped_at_status_deleted_at; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX idx_execution_entity_stopped_at_status_deleted_at ON public.execution_entity USING btree ("stoppedAt", status, "deletedAt") WHERE (("stoppedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- TOC entry 3868 (class 1259 OID 17215)
-- Name: idx_execution_entity_wait_till_status_deleted_at; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX idx_execution_entity_wait_till_status_deleted_at ON public.execution_entity USING btree ("waitTill", status, "deletedAt") WHERE (("waitTill" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- TOC entry 3869 (class 1259 OID 17214)
-- Name: idx_execution_entity_workflow_id_started_at; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX idx_execution_entity_workflow_id_started_at ON public.execution_entity USING btree ("workflowId", "startedAt") WHERE (("startedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- TOC entry 3883 (class 1259 OID 16814)
-- Name: idx_workflows_tags_workflow_id; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX idx_workflows_tags_workflow_id ON public.workflows_tags USING btree ("workflowId");


--
-- TOC entry 3865 (class 1259 OID 16855)
-- Name: pk_credentials_entity_id; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX pk_credentials_entity_id ON public.credentials_entity USING btree (id);


--
-- TOC entry 3880 (class 1259 OID 16811)
-- Name: pk_tag_entity_id; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX pk_tag_entity_id ON public.tag_entity USING btree (id);


--
-- TOC entry 3873 (class 1259 OID 16810)
-- Name: pk_workflow_entity_id; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX pk_workflow_entity_id ON public.workflow_entity USING btree (id);


--
-- TOC entry 3921 (class 1259 OID 17650)
-- Name: project_relation_role_idx; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX project_relation_role_idx ON public.project_relation USING btree (role);


--
-- TOC entry 3922 (class 1259 OID 17651)
-- Name: project_relation_role_project_idx; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX project_relation_role_project_idx ON public.project_relation USING btree ("projectId", role);


--
-- TOC entry 3890 (class 1259 OID 17652)
-- Name: user_role_idx; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE INDEX user_role_idx ON public."user" USING btree ("roleSlug");


--
-- TOC entry 3906 (class 1259 OID 17660)
-- Name: variables_global_key_unique; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX variables_global_key_unique ON public.variables USING btree (key) WHERE ("projectId" IS NULL);


--
-- TOC entry 3909 (class 1259 OID 17659)
-- Name: variables_project_key_unique; Type: INDEX; Schema: public; Owner: agente_user
--

CREATE UNIQUE INDEX variables_project_key_unique ON public.variables USING btree ("projectId", key) WHERE ("projectId" IS NOT NULL);


--
-- TOC entry 4138 (class 2620 OID 16452)
-- Name: problematicas tr_auditoria_insert; Type: TRIGGER; Schema: public; Owner: agente_user
--

CREATE TRIGGER tr_auditoria_insert AFTER INSERT ON public.problematicas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_insert();


--
-- TOC entry 4139 (class 2620 OID 16454)
-- Name: problematicas tr_auditoria_update; Type: TRIGGER; Schema: public; Owner: agente_user
--

CREATE TRIGGER tr_auditoria_update AFTER UPDATE ON public.problematicas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_update();


--
-- TOC entry 4140 (class 2620 OID 16441)
-- Name: problematicas trg_auditoria_insert; Type: TRIGGER; Schema: public; Owner: agente_user
--

CREATE TRIGGER trg_auditoria_insert AFTER INSERT ON public.problematicas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_insert();


--
-- TOC entry 4141 (class 2620 OID 17867)
-- Name: workflow_entity workflow_version_increment; Type: TRIGGER; Schema: public; Owner: agente_user
--

CREATE TRIGGER workflow_version_increment BEFORE UPDATE ON public.workflow_entity FOR EACH ROW EXECUTE FUNCTION public.increment_workflow_version();


--
-- TOC entry 4136 (class 2606 OID 18178)
-- Name: workflow_builder_session FK_00290cdeee4d4d7db84709be936; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "FK_00290cdeee4d4d7db84709be936" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4081 (class 2606 OID 17284)
-- Name: processed_data FK_06a69a7032c97a763c2c7599464; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "FK_06a69a7032c97a763c2c7599464" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4057 (class 2606 OID 17882)
-- Name: workflow_entity FK_08d6c67b7f722b0039d9d5ed620; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT "FK_08d6c67b7f722b0039d9d5ed620" FOREIGN KEY ("activeVersionId") REFERENCES public.workflow_history("versionId") ON DELETE RESTRICT;


--
-- TOC entry 4125 (class 2606 OID 18064)
-- Name: project_secrets_provider_access FK_18e5c27d2524b1638b292904e48; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "FK_18e5c27d2524b1638b292904e48" FOREIGN KEY ("secretsProviderConnectionId") REFERENCES public.secrets_provider_connection(id) ON DELETE CASCADE;


--
-- TOC entry 4086 (class 2606 OID 17990)
-- Name: insights_metadata FK_1d8ab99d5861c9388d2dc1cf733; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_1d8ab99d5861c9388d2dc1cf733" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4067 (class 2606 OID 16892)
-- Name: workflow_history FK_1e31657f5fe46816c34be7c1b4b; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "FK_1e31657f5fe46816c34be7c1b4b" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4101 (class 2606 OID 17728)
-- Name: chat_hub_messages FK_1f4998c8a7dec9e00a9ab15550e; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_1f4998c8a7dec9e00a9ab15550e" FOREIGN KEY ("revisionOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- TOC entry 4116 (class 2606 OID 17841)
-- Name: oauth_user_consents FK_21e6c3c2d78a097478fae6aaefa; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_21e6c3c2d78a097478fae6aaefa" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4087 (class 2606 OID 17481)
-- Name: insights_metadata FK_2375a1eda085adb16b24615b69c; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_2375a1eda085adb16b24615b69c" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE SET NULL;


--
-- TOC entry 4102 (class 2606 OID 17723)
-- Name: chat_hub_messages FK_25c9736e7f769f3a005eef4b372; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_25c9736e7f769f3a005eef4b372" FOREIGN KEY ("retryOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- TOC entry 4134 (class 2606 OID 18148)
-- Name: chat_hub_agent_tools FK_2b53d796b3dbae91b1a9553c048; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "FK_2b53d796b3dbae91b1a9553c048" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE CASCADE;


--
-- TOC entry 4076 (class 2606 OID 17201)
-- Name: execution_metadata FK_31d0b4c93fb85ced26f6005cda3; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "FK_31d0b4c93fb85ced26f6005cda3" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4072 (class 2606 OID 17156)
-- Name: shared_credentials FK_416f66fc846c7c442970c094ccf; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_416f66fc846c7c442970c094ccf" FOREIGN KEY ("credentialsId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4065 (class 2606 OID 17654)
-- Name: variables FK_42f6c766f9f9d2edcc15bdd6e9b; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT "FK_42f6c766f9f9d2edcc15bdd6e9b" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4135 (class 2606 OID 18153)
-- Name: chat_hub_agent_tools FK_43e70f04c53344f82483d0570f6; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "FK_43e70f04c53344f82483d0570f6" FOREIGN KEY ("toolId") REFERENCES public.chat_hub_tools(id) ON DELETE CASCADE;


--
-- TOC entry 4108 (class 2606 OID 17747)
-- Name: chat_hub_agents FK_441ba2caba11e077ce3fbfa2cd8; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_441ba2caba11e077ce3fbfa2cd8" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4127 (class 2606 OID 18081)
-- Name: workflow_published_version FK_5c76fb7ee939fe2530374d3f75a; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "FK_5c76fb7ee939fe2530374d3f75a" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4069 (class 2606 OID 17133)
-- Name: project_relation FK_5f0643f6717905a05164090dde7; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_5f0643f6717905a05164090dde7" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4070 (class 2606 OID 17128)
-- Name: project_relation FK_61448d56d61802b5dfde5cdb002; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_61448d56d61802b5dfde5cdb002" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4089 (class 2606 OID 17506)
-- Name: insights_by_period FK_6414cfed98daabbfdd61a1cfbc0; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "FK_6414cfed98daabbfdd61a1cfbc0" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- TOC entry 4110 (class 2606 OID 17780)
-- Name: oauth_authorization_codes FK_64d965bd072ea24fb6da55468cd; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_64d965bd072ea24fb6da55468cd" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- TOC entry 4132 (class 2606 OID 18138)
-- Name: chat_hub_session_tools FK_6596a328affd8d4967ffb303eee; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "FK_6596a328affd8d4967ffb303eee" FOREIGN KEY ("toolId") REFERENCES public.chat_hub_tools(id) ON DELETE CASCADE;


--
-- TOC entry 4103 (class 2606 OID 17733)
-- Name: chat_hub_messages FK_6afb260449dd7a9b85355d4e0c9; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_6afb260449dd7a9b85355d4e0c9" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4088 (class 2606 OID 17494)
-- Name: insights_raw FK_6e2e33741adef2a7c5d66befa4e; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "FK_6e2e33741adef2a7c5d66befa4e" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- TOC entry 4119 (class 2606 OID 17916)
-- Name: workflow_publish_history FK_6eab5bd9eedabe9c54bd879fc40; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_6eab5bd9eedabe9c54bd879fc40" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE SET NULL;


--
-- TOC entry 4122 (class 2606 OID 18032)
-- Name: dynamic_credential_user_entry FK_6edec973a6450990977bb854c38; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_6edec973a6450990977bb854c38" FOREIGN KEY ("resolverId") REFERENCES public.dynamic_credential_resolver(id) ON DELETE CASCADE;


--
-- TOC entry 4112 (class 2606 OID 17802)
-- Name: oauth_access_tokens FK_7234a36d8e49a1fa85095328845; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_7234a36d8e49a1fa85095328845" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4063 (class 2606 OID 16687)
-- Name: installed_nodes FK_73f857fc5dce682cef8a99c11dbddbc969618951; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "FK_73f857fc5dce682cef8a99c11dbddbc969618951" FOREIGN KEY (package) REFERENCES public.installed_packages("packageName") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4113 (class 2606 OID 17797)
-- Name: oauth_access_tokens FK_78b26968132b7e5e45b75876481; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_78b26968132b7e5e45b75876481" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- TOC entry 4137 (class 2606 OID 18173)
-- Name: workflow_builder_session FK_7983c618db48f47bf5a4cc1e1e4; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "FK_7983c618db48f47bf5a4cc1e1e4" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4097 (class 2606 OID 17682)
-- Name: chat_hub_sessions FK_7bc13b4c7e6afbfaf9be326c189; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_7bc13b4c7e6afbfaf9be326c189" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4082 (class 2606 OID 17398)
-- Name: folder FK_804ea52f6729e3940498bd54d78; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_804ea52f6729e3940498bd54d78" FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- TOC entry 4073 (class 2606 OID 17161)
-- Name: shared_credentials FK_812c2852270da1247756e77f5a4; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_812c2852270da1247756e77f5a4" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4091 (class 2606 OID 17536)
-- Name: test_case_execution FK_8e4b4774db42f1e6dda3452b2af; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_8e4b4774db42f1e6dda3452b2af" FOREIGN KEY ("testRunId") REFERENCES public.test_run(id) ON DELETE CASCADE;


--
-- TOC entry 4096 (class 2606 OID 17643)
-- Name: data_table_column FK_930b6e8faaf88294cef23484160; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "FK_930b6e8faaf88294cef23484160" FOREIGN KEY ("dataTableId") REFERENCES public.data_table(id) ON DELETE CASCADE;


--
-- TOC entry 4123 (class 2606 OID 18027)
-- Name: dynamic_credential_user_entry FK_945ba70b342a066d1306b12ccd2; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_945ba70b342a066d1306b12ccd2" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4084 (class 2606 OID 17409)
-- Name: folder_tag FK_94a60854e06f2897b2e0d39edba; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_94a60854e06f2897b2e0d39edba" FOREIGN KEY ("folderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- TOC entry 4077 (class 2606 OID 17228)
-- Name: execution_annotations FK_97f863fa83c4786f19565084960; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "FK_97f863fa83c4786f19565084960" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4109 (class 2606 OID 17752)
-- Name: chat_hub_agents FK_9c61ad497dcbae499c96a6a78ba; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_9c61ad497dcbae499c96a6a78ba" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4098 (class 2606 OID 17687)
-- Name: chat_hub_sessions FK_9f9293d9f552496c40e0d1a8f80; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_9f9293d9f552496c40e0d1a8f80" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4078 (class 2606 OID 17252)
-- Name: execution_annotation_tags FK_a3697779b366e131b2bbdae2976; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_a3697779b366e131b2bbdae2976" FOREIGN KEY ("tagId") REFERENCES public.annotation_tag_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4124 (class 2606 OID 18037)
-- Name: dynamic_credential_user_entry FK_a36dc616fabc3f736bb82410a22; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_a36dc616fabc3f736bb82410a22" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4074 (class 2606 OID 17187)
-- Name: shared_workflow FK_a45ea5f27bcfdc21af9b4188560; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_a45ea5f27bcfdc21af9b4188560" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4118 (class 2606 OID 17856)
-- Name: workflow_dependency FK_a4ff2d9b9628ea988fa9e7d0bf8; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "FK_a4ff2d9b9628ea988fa9e7d0bf8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4117 (class 2606 OID 17836)
-- Name: oauth_user_consents FK_a651acea2f6c97f8c4514935486; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_a651acea2f6c97f8c4514935486" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- TOC entry 4114 (class 2606 OID 17821)
-- Name: oauth_refresh_tokens FK_a699f3ed9fd0c1b19bc2608ac53; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_a699f3ed9fd0c1b19bc2608ac53" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4129 (class 2606 OID 18100)
-- Name: dynamic_credential_entry FK_a6d1dd080958304a47a02952aab; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "FK_a6d1dd080958304a47a02952aab" FOREIGN KEY (credential_id) REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4083 (class 2606 OID 17393)
-- Name: folder FK_a8260b0b36939c6247f385b8221; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_a8260b0b36939c6247f385b8221" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4111 (class 2606 OID 17785)
-- Name: oauth_authorization_codes FK_aa8d3560484944c19bdf79ffa16; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_aa8d3560484944c19bdf79ffa16" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4104 (class 2606 OID 17713)
-- Name: chat_hub_messages FK_acf8926098f063cdbbad8497fd1; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_acf8926098f063cdbbad8497fd1" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4115 (class 2606 OID 17816)
-- Name: oauth_refresh_tokens FK_b388696ce4d8be7ffbe8d3e4b69; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_b388696ce4d8be7ffbe8d3e4b69" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- TOC entry 4120 (class 2606 OID 17911)
-- Name: workflow_publish_history FK_b4cfbc7556d07f36ca177f5e473; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_b4cfbc7556d07f36ca177f5e473" FOREIGN KEY ("versionId") REFERENCES public.workflow_history("versionId") ON DELETE CASCADE;


--
-- TOC entry 4131 (class 2606 OID 18122)
-- Name: chat_hub_tools FK_b8030b47af9213f1fd15450fb7f; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_tools
    ADD CONSTRAINT "FK_b8030b47af9213f1fd15450fb7f" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4126 (class 2606 OID 18069)
-- Name: project_secrets_provider_access FK_bd264b81209355b543878deedb1; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "FK_bd264b81209355b543878deedb1" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4121 (class 2606 OID 17906)
-- Name: workflow_publish_history FK_c01316f8c2d7101ec4fa9809267; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_c01316f8c2d7101ec4fa9809267" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4079 (class 2606 OID 17247)
-- Name: execution_annotation_tags FK_c1519757391996eb06064f0e7c8; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_c1519757391996eb06064f0e7c8" FOREIGN KEY ("annotationId") REFERENCES public.execution_annotations(id) ON DELETE CASCADE;


--
-- TOC entry 4095 (class 2606 OID 17629)
-- Name: data_table FK_c2a794257dee48af7c9abf681de; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "FK_c2a794257dee48af7c9abf681de" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- TOC entry 4071 (class 2606 OID 17586)
-- Name: project_relation FK_c6b99592dc96b0d836d7a21db91; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_c6b99592dc96b0d836d7a21db91" FOREIGN KEY (role) REFERENCES public.role(slug);


--
-- TOC entry 4105 (class 2606 OID 17982)
-- Name: chat_hub_messages FK_chat_hub_messages_agentId; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_chat_hub_messages_agentId" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE SET NULL;


--
-- TOC entry 4099 (class 2606 OID 17977)
-- Name: chat_hub_sessions FK_chat_hub_sessions_agentId; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_chat_hub_sessions_agentId" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE SET NULL;


--
-- TOC entry 4130 (class 2606 OID 18105)
-- Name: dynamic_credential_entry FK_d61a12235d268a49af6a3c09c13; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "FK_d61a12235d268a49af6a3c09c13" FOREIGN KEY (resolver_id) REFERENCES public.dynamic_credential_resolver(id) ON DELETE CASCADE;


--
-- TOC entry 4090 (class 2606 OID 17521)
-- Name: test_run FK_d6870d3b6e4c185d33926f423c8; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "FK_d6870d3b6e4c185d33926f423c8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4075 (class 2606 OID 17182)
-- Name: shared_workflow FK_daa206a04983d47d0a9c34649ce; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_daa206a04983d47d0a9c34649ce" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4085 (class 2606 OID 17414)
-- Name: folder_tag FK_dc88164176283de80af47621746; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_dc88164176283de80af47621746" FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4128 (class 2606 OID 18086)
-- Name: workflow_published_version FK_df3428a541b802d6a63ac56e330; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "FK_df3428a541b802d6a63ac56e330" FOREIGN KEY ("publishedVersionId") REFERENCES public.workflow_history("versionId") ON DELETE CASCADE;


--
-- TOC entry 4080 (class 2606 OID 17268)
-- Name: user_api_keys FK_e131705cbbc8fb589889b02d457; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "FK_e131705cbbc8fb589889b02d457" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4106 (class 2606 OID 17703)
-- Name: chat_hub_messages FK_e22538eb50a71a17954cd7e076c; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e22538eb50a71a17954cd7e076c" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- TOC entry 4092 (class 2606 OID 17541)
-- Name: test_case_execution FK_e48965fac35d0f5b9e7f51d8c44; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_e48965fac35d0f5b9e7f51d8c44" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- TOC entry 4107 (class 2606 OID 17708)
-- Name: chat_hub_messages FK_e5d1fa722c5a8d38ac204746662; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e5d1fa722c5a8d38ac204746662" FOREIGN KEY ("previousMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- TOC entry 4133 (class 2606 OID 18133)
-- Name: chat_hub_session_tools FK_e649bf1295f4ed8d4299ed290f9; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "FK_e649bf1295f4ed8d4299ed290f9" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- TOC entry 4100 (class 2606 OID 17677)
-- Name: chat_hub_sessions FK_e9ecf8ede7d989fcd18790fe36a; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_e9ecf8ede7d989fcd18790fe36a" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- TOC entry 4062 (class 2606 OID 17581)
-- Name: user FK_eaea92ee7bfb9c1b6cd01505d56; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "FK_eaea92ee7bfb9c1b6cd01505d56" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug);


--
-- TOC entry 4093 (class 2606 OID 17569)
-- Name: role_scope FK_role; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_role" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4094 (class 2606 OID 17574)
-- Name: role_scope FK_scope; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_scope" FOREIGN KEY ("scopeSlug") REFERENCES public.scope(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4064 (class 2606 OID 16768)
-- Name: auth_identity auth_identity_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT "auth_identity_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."user"(id);


--
-- TOC entry 4055 (class 2606 OID 17960)
-- Name: credentials_entity credentials_entity_resolverId_foreign; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT "credentials_entity_resolverId_foreign" FOREIGN KEY ("resolverId") REFERENCES public.dynamic_credential_resolver(id) ON DELETE SET NULL;


--
-- TOC entry 4066 (class 2606 OID 16874)
-- Name: execution_data execution_data_fk; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_fk FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4054 (class 2606 OID 16428)
-- Name: favoritos favoritos_problematicas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_problematicas_id_fkey FOREIGN KEY (problematicas_id) REFERENCES public.problematicas(id);


--
-- TOC entry 4056 (class 2606 OID 16846)
-- Name: execution_entity fk_execution_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT fk_execution_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4059 (class 2606 OID 16840)
-- Name: webhook_entity fk_webhook_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT fk_webhook_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4058 (class 2606 OID 17465)
-- Name: workflow_entity fk_workflow_parent_folder; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT fk_workflow_parent_folder FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- TOC entry 4060 (class 2606 OID 16820)
-- Name: workflows_tags fk_workflows_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_tag_id FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4061 (class 2606 OID 16815)
-- Name: workflows_tags fk_workflows_tags_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- TOC entry 4068 (class 2606 OID 17922)
-- Name: project projects_creatorId_foreign; Type: FK CONSTRAINT; Schema: public; Owner: agente_user
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "projects_creatorId_foreign" FOREIGN KEY ("creatorId") REFERENCES public."user"(id) ON DELETE SET NULL;


-- Completed on 2026-04-06 00:51:03

--
-- PostgreSQL database dump complete
--

\unrestrict qCtWSxDcsuQyLVteZY38dMDzBCOPVExjbwZ3fPEqvcZXDXjCOU3LTUQ7EGmtkiS

