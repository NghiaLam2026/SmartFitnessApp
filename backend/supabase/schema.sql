-- Enable the vector extension
create extension if not exists vector;

-- user_progress

create table if not exists user_progress (
    progress_id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade,
    weight double precision,
    calories_burned integer,
    steps_count integer,
    date_logged timestamp default now()
);

--user_progress_embeddings

create table if not exists user_progress_embeddings(
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade,
    progress_id uuid references user_progress(progress_id) on delete cascade,
    embedding vector(768),
    created_at timestamp default now()
);

-- match_user_progress() RPC

create or replace function match_user_progress(
    query_embedding vector(768),
    match_count int,
    match_user uuid,
)
returns table (
    progress_id uuid,
    user_id uuid,
    weight double precision,
    calories_burned int,
    steps_count int,
    date_logged timestamp,
    similarity float
)
language sql stable as $$
    select
        up.progress_id,
        up.user_id,
        up.weight,
        up.calories_burned,
        up.steps_count,
        up.date_logged,
        1 - (upe.embedding <=> query_embedding) as similarity
    from user_progress up
    join user_progress_embeddings upe on up.progress_id = upe.progress_id
    where up.user_id = match_user
    order by similarity desc
    limit match_count;
$$;