CREATE TABLE user_progress (
  progress_id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date_logged DATE NOT NULL DEFAULT CURRENT_DATE,
  weight NUMERIC,
  calories_burned INTEGER,
  steps_count INTEGER,

  -- optional timestamp
  created_at TIMESTAMP DEFAULT NOW()
);


CREATE TABLE public.user_badges (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    progress_value numeric NOT NULL,
    unlocked_at timestamp without time zone DEFAULT timezone('utc', now()),
    icon_url text NOT NULL,
    progress_type text NOT NULL,
    badge_name text NOT NULL,
    description text NOT NULL
);


ALTER TABLE user_badges
ADD CONSTRAINT unique_user_badge UNIQUE (user_id, badge_name);





CREATE TABLE public.user_progress_embeddings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    progress_id integer NOT NULL REFERENCES public.user_progress(progress_id) ON DELETE CASCADE,
    embedding vector(768) NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc', now())
);







CREATE OR REPLACE FUNCTION match_user_progress(
  query_embedding vector(768),
  match_count int,
  match_user uuid
)
RETURNS TABLE (
  progress_id int,
  date_logged date,
  weight numeric,
  calories_burned int,
  steps_count int,
  similarity float
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT
      p.progress_id,
      p.date_logged,
      p.weight,
      p.calories_burned,
      p.steps_count,
      (e.embedding <-> query_embedding) AS similarity
    FROM user_progress_embeddings e
    JOIN user_progress p
      ON p.progress_id = e.progress_id
    WHERE e.user_id = match_user   -- FIX: specify table
    ORDER BY e.embedding <-> query_embedding
    LIMIT match_count;
END;
$$;


CREATE OR REPLACE FUNCTION match_user_progress_by_date(
  query_embedding vector(768),
  match_count int,
  match_user uuid
)
RETURNS TABLE (
  progress_id int,
  date_logged date,
  weight numeric,
  calories_burned int,
  steps_count int,
  similarity float
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT
      p.progress_id,
      p.date_logged,
      p.weight,
      p.calories_burned,
      p.steps_count,
      (e.embedding <-> query_embedding) AS similarity
    FROM user_progress_embeddings e
    JOIN user_progress p
      ON p.progress_id = e.progress_id
    WHERE e.user_id = match_user
    ORDER BY p.date_logged ASC       --  sorted by date
    LIMIT match_count;
END;
$$;


CREATE OR REPLACE FUNCTION match_user_progress_7days(
  query_embedding vector(768),
  match_count int,
  match_user uuid
)
RETURNS TABLE (
  progress_id int,
  date_logged date,
  weight numeric,
  calories_burned int,
  steps_count int,
  similarity float
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT
      p.progress_id,
      p.date_logged,
      p.weight,
      p.calories_burned,
      p.steps_count,
      (e.embedding <-> query_embedding) AS similarity
    FROM user_progress_embeddings e
    JOIN user_progress p
      ON p.progress_id = e.progress_id
    WHERE e.user_id = match_user
      AND p.date_logged >= NOW() - INTERVAL '7 days'
    ORDER BY e.embedding <-> query_embedding
    LIMIT match_count;
END;

