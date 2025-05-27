

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


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."user_type" AS ENUM (
    'owner',
    'staff'
);


ALTER TYPE "public"."user_type" OWNER TO "postgres";


COMMENT ON TYPE "public"."user_type" IS 'User Type';



CREATE OR REPLACE FUNCTION "public"."generate_username"("display_name" "text", "email" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$

DECLARE
  username_new text;
  username_length int := 4; -- you can adjust the starting length
  username_exists boolean;
BEGIN
  -- Generate username based on full name without spaces
  username_new := lower(regexp_replace(display_name, '[^\w]+', '', 'g'));

  -- Try to create a username with 5 characters
  username_new := substr(username_new, 1, username_length);

  -- Check if username already exists in profiles table
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE username = username_new) INTO username_exists;

  -- Increase username length gradually if needed
  WHILE username_exists AND username_length < length(username_new) LOOP
    username_length := username_length + 1;
    username_new := substr(username_new, 1, username_length);
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE username = username_new) INTO username_exists;
  END LOOP;

  -- If username still exists, try with underscore and check again
  IF username_exists THEN
    username_new := lower(regexp_replace(display_name, '[^\w]+', '_', 'g'));
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE username = username_new) INTO username_exists;
  END IF;

  -- If username still exists, try with hyphen and check again
  IF username_exists THEN
    username_new := lower(regexp_replace(display_name, '[^\w]+', '-', 'g'));
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE username = username_new) INTO username_exists;
  END IF;

  -- Return the generated username
  RETURN username_new;

END;
$$;


ALTER FUNCTION "public"."generate_username"("display_name" "text", "email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_workspace_id_from_room"("room_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT workspace_id FROM rooms WHERE id = room_id;
$$;


ALTER FUNCTION "public"."get_workspace_id_from_room"("room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_room_member"("uid" "uuid", "room_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $_$BEGIN
  
  RETURN EXISTS (
    SELECT 1
    FROM room_members rm
    JOIN profiles p ON p.id = rm.user_id
    WHERE rm.room_id = $2
      AND p.id = $1
  );

END;$_$;


ALTER FUNCTION "public"."is_room_member"("uid" "uuid", "room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_workspace_member"("uid" "uuid", "workspace_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $_$BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM workspace_members wm
    JOIN profiles p ON p.id = wm.user_id
    WHERE wm.workspace_id = $2
      AND p.id = $1
  );
END;$_$;


ALTER FUNCTION "public"."is_workspace_member"("uid" "uuid", "workspace_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_yourself_admin_room"("room_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $_$

BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.room_members
    WHERE room_members.room_id = $1
    AND room_members.user_id = auth.uid()
    AND room_members.role = 'admin'
  );
END;

$_$;


ALTER FUNCTION "public"."is_yourself_admin_room"("room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_yourself_member_room"("room_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $_$

BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.room_members
    WHERE room_members.room_id = $1
    AND room_members.user_id = auth.uid()
  );
END;

$_$;


ALTER FUNCTION "public"."is_yourself_member_room"("room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_yourself_workspace_admin"("workspace_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $_$BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.workspace_members
    WHERE workspace_members.workspace_id = $1
      AND workspace_members.user_id = auth.uid()
      AND workspace_members.role = 'admin'
  );
END;$_$;


ALTER FUNCTION "public"."is_yourself_workspace_admin"("workspace_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_yourself_workspace_member"("workspace_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $_$BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.workspace_members
    WHERE workspace_members.workspace_id = $1
    AND workspace_members.user_id = auth.uid()
  );
END;$_$;


ALTER FUNCTION "public"."is_yourself_workspace_member"("workspace_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."chatbots" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "image_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."chatbots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."message_mentions" (
    "message_id" "uuid" NOT NULL,
    "target_type" "text" DEFAULT '''user''::text'::"text" NOT NULL,
    "target_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."message_mentions" OWNER TO "postgres";


COMMENT ON TABLE "public"."message_mentions" IS 'Store id of user/team or track mention all which mentioned in the message. Target type must be (user/team/all). If mentioned all, target_id must be a hacky id "00000000-0000-0000-0000-000000000000"';



CREATE TABLE IF NOT EXISTS "public"."message_reactions" (
    "message_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "emoji" "text" NOT NULL,
    "react_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."message_reactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."message_read" (
    "message_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "read_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."message_read" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."message_removed" (
    "message_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."message_removed" OWNER TO "postgres";


COMMENT ON TABLE "public"."message_removed" IS 'List users have removed this message';



CREATE TABLE IF NOT EXISTS "public"."message_translations" (
    "message_id" "uuid" NOT NULL,
    "language_code" "text" NOT NULL,
    "translated_text" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."message_translations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sender" "uuid" DEFAULT "auth"."uid"(),
    "content" "text",
    "action" "text",
    "has_attachments" boolean DEFAULT false NOT NULL,
    "attachment_link" "text",
    "room_id" "uuid" NOT NULL,
    "language" "text" NOT NULL,
    "is_pinned" boolean NOT NULL,
    "is_forwarded" boolean NOT NULL,
    "is_quick_replied" boolean NOT NULL,
    "forward_of" "uuid",
    "quick_reply_of" "uuid",
    "parent" "uuid",
    "has_child" boolean NOT NULL,
    "new_reply_at" timestamp with time zone,
    "latest_reply" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "username" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "avatar_url" "text",
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "language" "text",
    "type" "text"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."language" IS 'User Main Language';



CREATE TABLE IF NOT EXISTS "public"."room_members" (
    "room_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "is_muted" boolean DEFAULT false NOT NULL,
    "last_read" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role" "text" DEFAULT 'member'::"text" NOT NULL
);


ALTER TABLE "public"."room_members" OWNER TO "postgres";


COMMENT ON TABLE "public"."room_members" IS 'Relation table of rooms and members';



CREATE TABLE IF NOT EXISTS "public"."rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "workspace_id" "uuid",
    "avatar_url" "text",
    "name" "text",
    "created_by" "uuid" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "is_group" boolean DEFAULT false NOT NULL,
    "deleted_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."waiting_rooms_members" (
    "room_id" "uuid" NOT NULL,
    "request_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL
);


ALTER TABLE "public"."waiting_rooms_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."workspace_members" (
    "workspace_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."workspace_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."workspaces" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "logo_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "owner_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "chatbot_id" "uuid"
);


ALTER TABLE "public"."workspaces" OWNER TO "postgres";


ALTER TABLE ONLY "public"."chatbots"
    ADD CONSTRAINT "chatbots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."message_mentions"
    ADD CONSTRAINT "message_mentions_pkey" PRIMARY KEY ("message_id", "target_type", "target_id");



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_pkey" PRIMARY KEY ("message_id", "user_id");



ALTER TABLE ONLY "public"."message_read"
    ADD CONSTRAINT "message_read_pkey" PRIMARY KEY ("message_id", "user_id");



ALTER TABLE ONLY "public"."message_removed"
    ADD CONSTRAINT "message_removed_pkey" PRIMARY KEY ("message_id", "user_id");



ALTER TABLE ONLY "public"."message_translations"
    ADD CONSTRAINT "message_translations_pkey" PRIMARY KEY ("message_id", "language_code");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."room_members"
    ADD CONSTRAINT "room_members_pkey" PRIMARY KEY ("room_id", "user_id");



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."waiting_rooms_members"
    ADD CONSTRAINT "waiting_rooms_members_pkey" PRIMARY KEY ("room_id", "user_id");



ALTER TABLE ONLY "public"."workspace_members"
    ADD CONSTRAINT "workspace_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."workspaces"
    ADD CONSTRAINT "workspaces_pkey" PRIMARY KEY ("id");



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."chatbots" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



ALTER TABLE ONLY "public"."message_mentions"
    ADD CONSTRAINT "message_mentions_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_read"
    ADD CONSTRAINT "message_read_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_read"
    ADD CONSTRAINT "message_read_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_removed"
    ADD CONSTRAINT "message_removed_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_removed"
    ADD CONSTRAINT "message_removed_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_translations"
    ADD CONSTRAINT "message_translations_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_forward_of_fkey" FOREIGN KEY ("forward_of") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_latest_reply_fkey" FOREIGN KEY ("latest_reply") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_parent_fkey" FOREIGN KEY ("parent") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_quick_reply_of_fkey" FOREIGN KEY ("quick_reply_of") REFERENCES "public"."messages"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_fkey1" FOREIGN KEY ("sender") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."room_members"
    ADD CONSTRAINT "room_members_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."room_members"
    ADD CONSTRAINT "room_members_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."waiting_rooms_members"
    ADD CONSTRAINT "waiting_rooms_members_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."rooms"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."waiting_rooms_members"
    ADD CONSTRAINT "waiting_rooms_members_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."workspace_members"
    ADD CONSTRAINT "workspace_members_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."workspace_members"
    ADD CONSTRAINT "workspace_members_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."workspaces"
    ADD CONSTRAINT "workspaces_chatbot_id_fkey" FOREIGN KEY ("chatbot_id") REFERENCES "public"."chatbots"("id");



ALTER TABLE ONLY "public"."workspaces"
    ADD CONSTRAINT "workspaces_owner_id_fkey1" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE SET NULL;



CREATE POLICY "Admin can remove member from their own room" ON "public"."room_members" FOR DELETE TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."room_members" "rm"
  WHERE (("rm"."room_id" = "room_members"."room_id") AND ("rm"."user_id" = "auth"."uid"()) AND ("rm"."role" = 'admin'::"text")))) AND ("user_id" <> "auth"."uid"())));



CREATE POLICY "Admins can add members to workspace" ON "public"."workspace_members" FOR INSERT WITH CHECK ("public"."is_yourself_workspace_admin"("workspace_id"));



CREATE POLICY "Admins can remove members from workspace" ON "public"."workspace_members" FOR DELETE USING ("public"."is_yourself_workspace_admin"("workspace_id"));



CREATE POLICY "Enable delete for owners through workspace" ON "public"."chatbots" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."workspaces" "w"
  WHERE (("w"."chatbot_id" = "chatbots"."id") AND ("w"."owner_id" = "auth"."uid"())))));



CREATE POLICY "Enable insert for authenticated users only" ON "public"."chatbots" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Enable insert for authenticated users only" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable members to view their joined rooms only" ON "public"."rooms" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."room_members"
     JOIN "public"."profiles" ON (("profiles"."id" = "room_members"."user_id")))
  WHERE (("room_members"."room_id" = "rooms"."id") AND ("profiles"."id" = "auth"."uid"())))));



CREATE POLICY "Enable read access for all users" ON "public"."chatbots" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."message_read" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."messages"
  WHERE (("messages"."id" = "message_read"."message_id") AND "public"."is_room_member"("auth"."uid"(), "messages"."room_id")))));



CREATE POLICY "Enable read access for all users" ON "public"."room_members" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."rooms" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."waiting_rooms_members" FOR SELECT USING (true);



CREATE POLICY "Enable update for owners through workspace" ON "public"."chatbots" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."workspaces" "w"
  WHERE (("w"."chatbot_id" = "chatbots"."id") AND ("w"."owner_id" = "auth"."uid"())))));



CREATE POLICY "Invited member can decline/accept the invitation" ON "public"."waiting_rooms_members" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Member can invite other members in workspace to room" ON "public"."waiting_rooms_members" FOR INSERT WITH CHECK (("public"."is_room_member"("auth"."uid"(), "room_id") AND "public"."is_workspace_member"("auth"."uid"(), "public"."get_workspace_id_from_room"("room_id")) AND "public"."is_workspace_member"("user_id", "public"."get_workspace_id_from_room"("room_id"))));



CREATE POLICY "Members can join room via the invitation" ON "public"."room_members" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."waiting_rooms_members" "wm"
  WHERE (("wm"."user_id" = "auth"."uid"()) AND ("wm"."room_id" = "room_members"."room_id")))));



CREATE POLICY "Members can leave room" ON "public"."room_members" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Members can leave workspace" ON "public"."workspace_members" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Members can view other members in their workspace" ON "public"."workspace_members" FOR SELECT USING ("public"."is_yourself_workspace_member"("workspace_id"));



CREATE POLICY "Room members can read messages" ON "public"."messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."room_members"
  WHERE (("room_members"."room_id" = "messages"."room_id") AND ("room_members"."user_id" = "auth"."uid"())))));



CREATE POLICY "Room members can send messages" ON "public"."messages" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."room_members"
  WHERE (("room_members"."room_id" = "messages"."room_id") AND ("room_members"."user_id" = "auth"."uid"())))) AND ("sender" = "auth"."uid"())));



CREATE POLICY "Users can create workspaces" ON "public"."workspaces" FOR INSERT WITH CHECK (("auth"."uid"() = "owner_id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view all profiles" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Users can view workspaces they belong to" ON "public"."workspaces" FOR SELECT USING (("public"."is_yourself_workspace_member"("id") OR ("owner_id" = "auth"."uid"())));



CREATE POLICY "Workspace owners can delete workspaces" ON "public"."workspaces" FOR DELETE USING (("auth"."uid"() = "owner_id"));



CREATE POLICY "Workspace owners can update workspaces" ON "public"."workspaces" FOR UPDATE USING (("auth"."uid"() = "owner_id"));



ALTER TABLE "public"."chatbots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_mentions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_reactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_read" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_removed" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_translations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."room_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rooms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."waiting_rooms_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."workspace_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."workspaces" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."message_mentions";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."message_reactions";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."message_read";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."message_removed";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."message_translations";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."profiles";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."room_members";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."rooms";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."waiting_rooms_members";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."workspace_members";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."workspaces";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."generate_username"("display_name" "text", "email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_username"("display_name" "text", "email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_username"("display_name" "text", "email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_workspace_id_from_room"("room_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_workspace_id_from_room"("room_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_workspace_id_from_room"("room_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_room_member"("uid" "uuid", "room_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_room_member"("uid" "uuid", "room_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_room_member"("uid" "uuid", "room_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_workspace_member"("uid" "uuid", "workspace_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_workspace_member"("uid" "uuid", "workspace_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_workspace_member"("uid" "uuid", "workspace_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_yourself_admin_room"("room_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_yourself_admin_room"("room_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_yourself_admin_room"("room_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_yourself_member_room"("room_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_yourself_member_room"("room_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_yourself_member_room"("room_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_yourself_workspace_admin"("workspace_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_yourself_workspace_admin"("workspace_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_yourself_workspace_admin"("workspace_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_yourself_workspace_member"("workspace_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_yourself_workspace_member"("workspace_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_yourself_workspace_member"("workspace_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."chatbots" TO "anon";
GRANT ALL ON TABLE "public"."chatbots" TO "authenticated";
GRANT ALL ON TABLE "public"."chatbots" TO "service_role";



GRANT ALL ON TABLE "public"."message_mentions" TO "anon";
GRANT ALL ON TABLE "public"."message_mentions" TO "authenticated";
GRANT ALL ON TABLE "public"."message_mentions" TO "service_role";



GRANT ALL ON TABLE "public"."message_reactions" TO "anon";
GRANT ALL ON TABLE "public"."message_reactions" TO "authenticated";
GRANT ALL ON TABLE "public"."message_reactions" TO "service_role";



GRANT ALL ON TABLE "public"."message_read" TO "anon";
GRANT ALL ON TABLE "public"."message_read" TO "authenticated";
GRANT ALL ON TABLE "public"."message_read" TO "service_role";



GRANT ALL ON TABLE "public"."message_removed" TO "anon";
GRANT ALL ON TABLE "public"."message_removed" TO "authenticated";
GRANT ALL ON TABLE "public"."message_removed" TO "service_role";



GRANT ALL ON TABLE "public"."message_translations" TO "anon";
GRANT ALL ON TABLE "public"."message_translations" TO "authenticated";
GRANT ALL ON TABLE "public"."message_translations" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."room_members" TO "anon";
GRANT ALL ON TABLE "public"."room_members" TO "authenticated";
GRANT ALL ON TABLE "public"."room_members" TO "service_role";



GRANT ALL ON TABLE "public"."rooms" TO "anon";
GRANT ALL ON TABLE "public"."rooms" TO "authenticated";
GRANT ALL ON TABLE "public"."rooms" TO "service_role";



GRANT ALL ON TABLE "public"."waiting_rooms_members" TO "anon";
GRANT ALL ON TABLE "public"."waiting_rooms_members" TO "authenticated";
GRANT ALL ON TABLE "public"."waiting_rooms_members" TO "service_role";



GRANT ALL ON TABLE "public"."workspace_members" TO "anon";
GRANT ALL ON TABLE "public"."workspace_members" TO "authenticated";
GRANT ALL ON TABLE "public"."workspace_members" TO "service_role";



GRANT ALL ON TABLE "public"."workspaces" TO "anon";
GRANT ALL ON TABLE "public"."workspaces" TO "authenticated";
GRANT ALL ON TABLE "public"."workspaces" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
