ALTER TABLE public.message_translations
ADD COLUMN IF NOT EXISTS is_original boolean DEFAULT false NOT NULL;

INSERT INTO public.message_translations (message_id, language, translated_text, is_original, created_at, updated_at)
SELECT 
    id AS message_id,
    language AS language_code,
    content AS translated_text,
    true AS is_original,
    now() AS created_at,
    now() AS updated_at
FROM public.messages
WHERE content IS NOT NULL;

ALTER TABLE public.messages
DROP COLUMN IF EXISTS content;