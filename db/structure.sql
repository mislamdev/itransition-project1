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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    user_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: field_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_values (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    field_id bigint NOT NULL,
    text_value text,
    number_value numeric(20,6),
    boolean_value boolean,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: field_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.field_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: field_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.field_values_id_seq OWNED BY public.field_values.id;


--
-- Name: fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fields (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    field_type character varying NOT NULL,
    show_in_table boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    options json DEFAULT '{}'::json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fields_id_seq OWNED BY public.fields.id;


--
-- Name: id_format_elements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.id_format_elements (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    kind character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    text character varying,
    options json DEFAULT '{}'::json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: id_format_elements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.id_format_elements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: id_format_elements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.id_format_elements_id_seq OWNED BY public.id_format_elements.id;


--
-- Name: inventories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    category_id bigint,
    image_url character varying,
    is_public boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)))) STORED,
    items_count integer DEFAULT 0 NOT NULL
);


--
-- Name: inventories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inventories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inventories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inventories_id_seq OWNED BY public.inventories.id;


--
-- Name: inventory_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_accesses (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inventory_accesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inventory_accesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inventory_accesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inventory_accesses_id_seq OWNED BY public.inventory_accesses.id;


--
-- Name: inventory_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_sequences (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    id_format_element_id bigint NOT NULL,
    value integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inventory_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inventory_sequences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inventory_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inventory_sequences_id_seq OWNED BY public.inventory_sequences.id;


--
-- Name: inventory_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_tags (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inventory_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inventory_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inventory_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inventory_tags_id_seq OWNED BY public.inventory_tags.id;


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id bigint NOT NULL,
    inventory_id bigint NOT NULL,
    custom_id character varying NOT NULL,
    created_by_id bigint,
    likes_count integer DEFAULT 0 NOT NULL,
    search_text text DEFAULT ''::text NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, COALESCE(search_text, ''::text))) STORED
);


--
-- Name: items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.items_id_seq OWNED BY public.items.id;


--
-- Name: likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.likes (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: likes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.likes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: likes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.likes_id_seq OWNED BY public.likes.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    password_digest character varying,
    name character varying DEFAULT ''::character varying NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    blocked boolean DEFAULT false NOT NULL,
    provider character varying,
    uid character varying,
    avatar_url character varying,
    locale character varying DEFAULT 'en'::character varying NOT NULL,
    theme character varying DEFAULT 'light'::character varying NOT NULL,
    session_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: field_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_values ALTER COLUMN id SET DEFAULT nextval('public.field_values_id_seq'::regclass);


--
-- Name: fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fields ALTER COLUMN id SET DEFAULT nextval('public.fields_id_seq'::regclass);


--
-- Name: id_format_elements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.id_format_elements ALTER COLUMN id SET DEFAULT nextval('public.id_format_elements_id_seq'::regclass);


--
-- Name: inventories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventories ALTER COLUMN id SET DEFAULT nextval('public.inventories_id_seq'::regclass);


--
-- Name: inventory_accesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_accesses ALTER COLUMN id SET DEFAULT nextval('public.inventory_accesses_id_seq'::regclass);


--
-- Name: inventory_sequences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_sequences ALTER COLUMN id SET DEFAULT nextval('public.inventory_sequences_id_seq'::regclass);


--
-- Name: inventory_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_tags ALTER COLUMN id SET DEFAULT nextval('public.inventory_tags_id_seq'::regclass);


--
-- Name: items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items ALTER COLUMN id SET DEFAULT nextval('public.items_id_seq'::regclass);


--
-- Name: likes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes ALTER COLUMN id SET DEFAULT nextval('public.likes_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: field_values field_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_values
    ADD CONSTRAINT field_values_pkey PRIMARY KEY (id);


--
-- Name: fields fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (id);


--
-- Name: id_format_elements id_format_elements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.id_format_elements
    ADD CONSTRAINT id_format_elements_pkey PRIMARY KEY (id);


--
-- Name: inventories inventories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventories
    ADD CONSTRAINT inventories_pkey PRIMARY KEY (id);


--
-- Name: inventory_accesses inventory_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_accesses
    ADD CONSTRAINT inventory_accesses_pkey PRIMARY KEY (id);


--
-- Name: inventory_sequences inventory_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_sequences
    ADD CONSTRAINT inventory_sequences_pkey PRIMARY KEY (id);


--
-- Name: inventory_tags inventory_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_tags
    ADD CONSTRAINT inventory_tags_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_on_inventory_id_id_format_element_id_485c65b48c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_inventory_id_id_format_element_id_485c65b48c ON public.inventory_sequences USING btree (inventory_id, id_format_element_id);


--
-- Name: index_categories_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_position ON public.categories USING btree ("position");


--
-- Name: index_categories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_slug ON public.categories USING btree (slug);


--
-- Name: index_comments_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_inventory_id ON public.comments USING btree (inventory_id);


--
-- Name: index_comments_on_inventory_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_inventory_id_and_created_at ON public.comments USING btree (inventory_id, created_at);


--
-- Name: index_comments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_user_id ON public.comments USING btree (user_id);


--
-- Name: index_field_values_on_field_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_field_values_on_field_id ON public.field_values USING btree (field_id);


--
-- Name: index_field_values_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_field_values_on_item_id ON public.field_values USING btree (item_id);


--
-- Name: index_field_values_on_item_id_and_field_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_field_values_on_item_id_and_field_id ON public.field_values USING btree (item_id, field_id);


--
-- Name: index_fields_on_field_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fields_on_field_type ON public.fields USING btree (field_type);


--
-- Name: index_fields_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fields_on_inventory_id ON public.fields USING btree (inventory_id);


--
-- Name: index_fields_on_inventory_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fields_on_inventory_id_and_position ON public.fields USING btree (inventory_id, "position");


--
-- Name: index_id_format_elements_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_id_format_elements_on_inventory_id ON public.id_format_elements USING btree (inventory_id);


--
-- Name: index_id_format_elements_on_inventory_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_id_format_elements_on_inventory_id_and_position ON public.id_format_elements USING btree (inventory_id, "position");


--
-- Name: index_inventories_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventories_on_category_id ON public.inventories USING btree (category_id);


--
-- Name: index_inventories_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventories_on_created_at ON public.inventories USING btree (created_at);


--
-- Name: index_inventories_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventories_on_search_vector ON public.inventories USING gin (search_vector);


--
-- Name: index_inventories_on_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventories_on_title ON public.inventories USING btree (title);


--
-- Name: index_inventories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventories_on_user_id ON public.inventories USING btree (user_id);


--
-- Name: index_inventory_accesses_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_accesses_on_inventory_id ON public.inventory_accesses USING btree (inventory_id);


--
-- Name: index_inventory_accesses_on_inventory_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inventory_accesses_on_inventory_id_and_user_id ON public.inventory_accesses USING btree (inventory_id, user_id);


--
-- Name: index_inventory_accesses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_accesses_on_user_id ON public.inventory_accesses USING btree (user_id);


--
-- Name: index_inventory_sequences_on_id_format_element_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_sequences_on_id_format_element_id ON public.inventory_sequences USING btree (id_format_element_id);


--
-- Name: index_inventory_sequences_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_sequences_on_inventory_id ON public.inventory_sequences USING btree (inventory_id);


--
-- Name: index_inventory_tags_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_tags_on_inventory_id ON public.inventory_tags USING btree (inventory_id);


--
-- Name: index_inventory_tags_on_inventory_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inventory_tags_on_inventory_id_and_tag_id ON public.inventory_tags USING btree (inventory_id, tag_id);


--
-- Name: index_inventory_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_tags_on_tag_id ON public.inventory_tags USING btree (tag_id);


--
-- Name: index_items_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_created_at ON public.items USING btree (created_at);


--
-- Name: index_items_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_created_by_id ON public.items USING btree (created_by_id);


--
-- Name: index_items_on_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_inventory_id ON public.items USING btree (inventory_id);


--
-- Name: index_items_on_inventory_id_and_custom_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_items_on_inventory_id_and_custom_id ON public.items USING btree (inventory_id, custom_id);


--
-- Name: index_items_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_search_vector ON public.items USING gin (search_vector);


--
-- Name: index_likes_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_likes_on_item_id ON public.likes USING btree (item_id);


--
-- Name: index_likes_on_item_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_likes_on_item_id_and_user_id ON public.likes USING btree (item_id, user_id);


--
-- Name: index_likes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_likes_on_user_id ON public.likes USING btree (user_id);


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_name ON public.tags USING btree (name);


--
-- Name: index_tags_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_slug ON public.tags USING btree (slug);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_name ON public.users USING btree (name);


--
-- Name: index_users_on_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_provider ON public.users USING btree (provider);


--
-- Name: index_users_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_provider_and_uid ON public.users USING btree (provider, uid);


--
-- Name: index_users_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_uid ON public.users USING btree (uid);


--
-- Name: likes fk_rails_00045f60f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT fk_rails_00045f60f7 FOREIGN KEY (item_id) REFERENCES public.items(id);


--
-- Name: comments fk_rails_03de2dc08c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_03de2dc08c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: likes fk_rails_1e09b5dabf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT fk_rails_1e09b5dabf FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: comments fk_rails_2990101834; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_2990101834 FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: inventory_tags fk_rails_5f772404da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_tags
    ADD CONSTRAINT fk_rails_5f772404da FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: inventories fk_rails_6642cbdd87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventories
    ADD CONSTRAINT fk_rails_6642cbdd87 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: inventory_tags fk_rails_6656edb749; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_tags
    ADD CONSTRAINT fk_rails_6656edb749 FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: items fk_rails_86c1b16e97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT fk_rails_86c1b16e97 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: field_values fk_rails_8c67d6ccf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_values
    ADD CONSTRAINT fk_rails_8c67d6ccf0 FOREIGN KEY (item_id) REFERENCES public.items(id);


--
-- Name: inventory_accesses fk_rails_8fc9e0bcdc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_accesses
    ADD CONSTRAINT fk_rails_8fc9e0bcdc FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: id_format_elements fk_rails_b81ccfff7d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.id_format_elements
    ADD CONSTRAINT fk_rails_b81ccfff7d FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: field_values fk_rails_bc57e805c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_values
    ADD CONSTRAINT fk_rails_bc57e805c5 FOREIGN KEY (field_id) REFERENCES public.fields(id);


--
-- Name: inventories fk_rails_c3ddaea441; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventories
    ADD CONSTRAINT fk_rails_c3ddaea441 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: inventory_accesses fk_rails_c89bc0cfec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_accesses
    ADD CONSTRAINT fk_rails_c89bc0cfec FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: items fk_rails_de1a7d75f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT fk_rails_de1a7d75f9 FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: fields fk_rails_e5915a705a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fields
    ADD CONSTRAINT fk_rails_e5915a705a FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: inventory_sequences fk_rails_eaf84b4edf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_sequences
    ADD CONSTRAINT fk_rails_eaf84b4edf FOREIGN KEY (inventory_id) REFERENCES public.inventories(id);


--
-- Name: inventory_sequences fk_rails_ef56b7a3d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_sequences
    ADD CONSTRAINT fk_rails_ef56b7a3d8 FOREIGN KEY (id_format_element_id) REFERENCES public.id_format_elements(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261115202115'),
('20261115202114'),
('20261115202113'),
('20261115202112'),
('20261115202111'),
('20261115202110'),
('20261115202109'),
('20261115202108'),
('20261115202107'),
('20261115202106'),
('20261115202105'),
('20261115202104'),
('20261115202103'),
('20261115202102'),
('20261115202101'),
('20261115202100');

