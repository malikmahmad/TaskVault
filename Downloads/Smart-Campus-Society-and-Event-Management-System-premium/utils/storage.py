import uuid
from typing import Optional
from supabase import Client


def upload_image(supabase: Client, bucket: str, uploaded_file) -> Optional[str]:
    """Upload a Streamlit UploadedFile to a public Supabase Storage bucket.
    Returns the public URL, or None if no file / on failure."""
    if uploaded_file is None:
        return None

    ext = (uploaded_file.name.rsplit(".", 1)[-1] if "." in uploaded_file.name else "png").lower()
    path = f"{uuid.uuid4()}.{ext}"

    content_type = uploaded_file.type or "image/png"
    file_bytes = uploaded_file.getvalue()

    supabase.storage.from_(bucket).upload(
        path, file_bytes, {"content-type": content_type}
    )
    return supabase.storage.from_(bucket).get_public_url(path)
