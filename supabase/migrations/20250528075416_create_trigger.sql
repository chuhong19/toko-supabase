drop policy "Enable read access for all users" on "public"."message_mentions";

drop policy "Enable read access for all users" on "public"."message_reactions";

drop policy "Enable read access for all users" on "public"."message_read";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.add_sender_seen_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$BEGIN
    INSERT INTO public.message_read (message_id, user_id, read_at)
    VALUES (NEW.id, NEW.sender, now());
    RETURN NEW;
END;$function$
;

CREATE OR REPLACE FUNCTION public.set_room_owner()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$BEGIN
    INSERT INTO public.room_members (room_id, user_id, role)
    VALUES (NEW.id, NEW.created_by, 'owner');
    RETURN NEW;
END;$function$
;

create policy "Enable read access for room members"
on "public"."message_mentions"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM messages
  WHERE ((messages.id = message_mentions.message_id) AND is_room_member(auth.uid(), messages.room_id)))));


create policy "Everyone in room can be mentioned"
on "public"."message_mentions"
as permissive
for insert
to public
with check (true);


create policy "Members of room can react message"
on "public"."message_reactions"
as permissive
for insert
to authenticated
with check ((EXISTS ( SELECT 1
   FROM messages
  WHERE ((messages.id = message_reactions.message_id) AND is_room_member(auth.uid(), messages.room_id) AND (message_reactions.user_id = auth.uid())))));


create policy "Room members can see every reactions"
on "public"."message_reactions"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM messages
  WHERE ((messages.id = message_reactions.message_id) AND is_room_member(auth.uid(), messages.room_id)))));


create policy "Enable read access for room members"
on "public"."message_read"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM messages
  WHERE ((messages.id = message_read.message_id) AND is_room_member(auth.uid(), messages.room_id)))));


create policy "Members of room can seen message"
on "public"."message_read"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM messages
  WHERE ((messages.id = message_read.message_id) AND is_room_member(auth.uid(), messages.room_id) AND (message_read.user_id = auth.uid())))));


CREATE TRIGGER add_sender_seen_status AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION add_sender_seen_status();

CREATE TRIGGER add_owner_to_room_members AFTER INSERT ON public.room_members FOR EACH ROW EXECUTE FUNCTION set_room_owner();


