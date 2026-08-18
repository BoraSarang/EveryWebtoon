import os
import re
import zipfile
from xml.sax.saxutils import escape

_MEDIA_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".xhtml": "application/xhtml+xml",
    ".ncx": "application/x-dtbncx+xml",
}


def _sanitize_path(name: str) -> str:
    return re.sub(r'[\\/:*?"<>|]', "_", name).strip()


def _episode_dir(output_base: str, title_name: str, episode_no: int) -> str:
    safe = _sanitize_path(title_name).rstrip(".")
    if not safe or safe in (".", ".."):
        safe = "unknown_title"
    return os.path.join(output_base, safe, f"{episode_no:03d}")


def _collect_images(ep_dir: str) -> list:
    images = sorted(
        f for f in os.listdir(ep_dir)
        if f.endswith((".jpg", ".jpeg", ".png", ".gif", ".webp"))
    )
    if not images:
        raise ValueError(f"No images found for episode {os.path.basename(ep_dir)}")
    if not os.path.exists(os.path.join(ep_dir, ".done")) and os.path.exists(os.path.join(ep_dir, ".partial")):
        raise ValueError(f"Episode {os.path.basename(ep_dir)} is not fully downloaded (.partial exists)")
    return images


def _export_dir(output_base: str, title_name: str) -> str:
    safe = _sanitize_path(title_name).rstrip(".")
    if not safe or safe in (".", ".."):
        safe = "unknown_title"
    export_dir = os.path.join(output_base, "_export", safe)
    os.makedirs(export_dir, exist_ok=True)
    return export_dir


def export_episode_cbz(output_base: str, title_name: str, episode_no: int) -> str:
    ep_dir = _episode_dir(output_base, title_name, episode_no)
    images = _collect_images(ep_dir)
    export_dir = _export_dir(output_base, title_name)
    cbz_path = os.path.join(export_dir, f"{episode_no:03d}.cbz")

    with zipfile.ZipFile(cbz_path, "w", zipfile.ZIP_STORED) as zf:
        for name in images:
            zf.write(os.path.join(ep_dir, name), name)

    return cbz_path


_PAGE_XHTML = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!DOCTYPE html>\n'
    '<html xmlns="http://www.w3.org/1999/xhtml">\n'
    "<head><title>{title}</title></head>\n"
    "<body>\n"
    '<div style="text-align:center;margin:0">\n'
    '<img src="../Images/{img}" alt="page" style="width:100%;height:auto;max-width:100%"/>\n'
    "</div>\n"
    "</body>\n"
    "</html>"
)

_NAV_XHTML = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!DOCTYPE html>\n'
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">\n'
    "<head><title>목차</title></head>\n"
    "<body>\n"
    '<nav epub:type="toc" id="toc"><h1>{title}</h1>\n<ol>\n'
    "{items}"
    "</ol></nav>\n"
    "</body>\n"
    "</html>"
)

_NCX = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">\n'
    "<head>\n"
    '<meta name="dtb:uid" content="{uid}"/>\n'
    '<meta name="dtb:depth" content="1"/>\n'
    '<meta name="dtb:totalPageCount" content="0"/>\n'
    '<meta name="dtb:maxPageNumber" content="0"/>\n'
    "</head>\n"
    "<docTitle><text>{title}</text></docTitle>\n"
    "<navMap>\n"
    "{items}"
    "</navMap>\n"
    "</ncx>"
)


def _unique_id(title_name: str, episode_no: int) -> str:
    import hashlib
    return hashlib.sha256(f"{title_name}|{episode_no}".encode("utf-8")).hexdigest()[:16]


def export_episode_epub(output_base: str, title_name: str, episode_no: int) -> str:
    ep_dir = _episode_dir(output_base, title_name, episode_no)
    images = _collect_images(ep_dir)
    export_dir = _export_dir(output_base, title_name)
    epub_path = os.path.join(export_dir, f"{episode_no:03d}.epub")

    book_title = f"{title_name} {episode_no}화"
    uid = _unique_id(title_name, episode_no)
    safe_title = escape(book_title)
    safe_title_name = escape(title_name)

    pages = [f"page{i + 1:04d}" for i in range(len(images))]
    img_exts = [os.path.splitext(name)[1].lower() for name in images]

    spine_items = ""
    nav_items = ""
    ncx_items = ""
    manifest = (
        f'<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" '
        f'properties="nav"/>\n'
    )
    manifest += (
        f'<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>\n'
    )
    for page, ext in zip(pages, img_exts):
        manifest += (
            f'<item id="page_{page}" href="Text/{page}.xhtml" '
            f'media-type="application/xhtml+xml"/>\n'
        )
        manifest += (
            f'<item id="img_{page}" href="Images/{page}{ext}" '
            f'media-type="{_MEDIA_TYPES[ext]}"/>\n'
        )
    for i, page in enumerate(pages, start=1):
        spine_items += f'<itemref idref="page_{page}"/>\n'
        nav_items += (
            f'<li><a href="Text/{page}.xhtml">{i}페이지</a></li>\n'
        )
        ncx_items += (
            f'<navPoint id="np_{page}" playOrder="{i}">'
            f'<navLabel><text>{i}페이지</text></navLabel>'
            f'<content src="Text/{page}.xhtml"/></navPoint>\n'
        )

    opf = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">\n'
        "<metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n"
        f'<dc:identifier id="bookid">urn:uuid:{uid}</dc:identifier>\n'
        f"<dc:title>{safe_title}</dc:title>\n"
        f"<dc:creator>{safe_title_name}</dc:creator>\n"
        "<dc:language>ko</dc:language>\n"
        "<dc:publisher>EveryWebtoon</dc:publisher>\n"
        "</metadata>\n"
        "<manifest>\n"
        f"{manifest}"
        "</manifest>\n"
        "<spine toc=\"ncx\">\n"
        f"{spine_items}"
        "</spine>\n"
        "</package>"
    )
    nav_html = _NAV_XHTML.format(title=safe_title, items=nav_items)
    ncx = _NCX.format(uid=uid, title=safe_title, items=ncx_items)

    with zipfile.ZipFile(epub_path, "w") as zf:
        mi = zipfile.ZipInfo("mimetype")
        mi.compress_type = zipfile.ZIP_STORED
        zf.writestr(mi, "application/epub+zip")
        zf.writestr("META-INF/container.xml", (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="OEBPS/content.opf" '
            'media-type="application/oebps-package+xml"/></rootfiles>'
            "</container>"
        ))
        zf.writestr("OEBPS/content.opf", opf)
        zf.writestr("OEBPS/nav.xhtml", nav_html)
        zf.writestr("OEBPS/toc.ncx", ncx)
        for i, (page, name) in enumerate(zip(pages, images), start=1):
            ext = os.path.splitext(name)[1].lower()
            zf.write(os.path.join(ep_dir, name), f"OEBPS/Images/{page}{ext}")
            zf.writestr(f"OEBPS/Text/{page}.xhtml", _PAGE_XHTML.format(
                title=f"{i}페이지", img=f"{page}{ext}"
            ))

    return epub_path
