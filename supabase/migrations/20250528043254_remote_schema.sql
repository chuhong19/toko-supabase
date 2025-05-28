alter table "public"."message_translations" drop constraint "message_translations_pkey";

drop index if exists "public"."message_translations_pkey";

alter table "public"."message_translations" drop column "language_code";

alter table "public"."message_translations" add column "language" text not null;

alter table "public"."messages" add column "content_english" text;

alter table "public"."messages" disable row level security;

alter table "public"."rooms" disable row level security;

alter table "public"."workspace_members" disable row level security;

alter table "public"."workspaces" add column "code" uuid not null default uuid_generate_v4();

CREATE UNIQUE INDEX workspaces_code_key ON public.workspaces USING btree (code);

CREATE UNIQUE INDEX message_translations_pkey ON public.message_translations USING btree (message_id, language);

alter table "public"."message_translations" add constraint "message_translations_pkey" PRIMARY KEY using index "message_translations_pkey";

alter table "public"."workspaces" add constraint "workspaces_code_key" UNIQUE using index "workspaces_code_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.reset_workspace_code(workspace_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    new_code uuid;
    rows_affected integer;
    user_role text;
BEGIN
    -- Get the user's role first
    SELECT role INTO user_role
    FROM workspace_members 
    WHERE workspace_members.workspace_id = reset_workspace_code.workspace_id 
    AND user_id = auth.uid();

    -- Check if user has permission
    IF user_role NOT IN ('owner', 'admin') THEN
        RAISE EXCEPTION 'Permission denied. User must be an owner or admin.';
    END IF;

    -- Generate new UUID for the code
    new_code := extensions.uuid_generate_v4();
    
    -- Update the workspace with the new code
    UPDATE workspaces
    SET code = new_code,
        updated_at = now()
    WHERE id = workspace_id
    RETURNING 1 INTO rows_affected;

    -- Check if update was successful
    IF rows_affected = 0 THEN
        RAISE EXCEPTION 'Workspace not found or update failed.';
    END IF;
    
    -- Return the new code
    RETURN new_code;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_workspace_owner()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$BEGIN
    INSERT INTO public.workspace_members (workspace_id, user_id, role)
    VALUES (NEW.id, NEW.owner_id, 'owner');
    RETURN NEW;
END;$function$
;

CREATE TRIGGER add_owner_to_workspace_members AFTER INSERT ON public.workspaces FOR EACH ROW EXECUTE FUNCTION set_workspace_owner();


