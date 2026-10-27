#!/usr/bin/env python3
"""从目录生成站点数据：首页课程列表、课程文件清单、sitemap 与 robots。

用法：python3 tools/build_site.py
"""
import json
import os
import re
from urllib.parse import quote

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
TERMS = [("大一上", "23F"), ("大一下", "23S"), ("大二上", "24F"),
         ("大二下", "24S"), ("大三上", "25F"), ("大三下", "25S")]
SITE = "https://ancher-puppet.github.io/ZJU-ISEE-IE"
BRANCH = "main"

DAY_RE = re.compile(
    r'<article class="day" data-reveal id="term-(\d)">\s*'
    r'<div class="day-head">.*?</div>\s*'
    r'<ul class="day-grid"[^>]*>(.*?)</ul>\s*</article>', re.S)
CARD_RE = re.compile(r'<a class="cname"[^>]*>(.*?)</a><span class="ccred">([\d.]*)</span>')


def read_course(term, name):
    path = os.path.join(ROOT, term, name, "课程体验.md")
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    credits = re.search(r"学分：\s*([\d.]+)", text)
    return {
        "name": name,
        "term": term,
        "credits": float(credits.group(1)) if credits else None,
        "notes": True,
    }


def scan_files(term, name):
    base = os.path.join(ROOT, term, name)
    rows = []
    for folder, dirs, files in os.walk(base):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for filename in sorted(files):
            if filename.startswith("."):
                continue
            full = os.path.join(folder, filename)
            rel = os.path.relpath(full, base).replace(os.sep, "/")
            rows.append([rel, os.path.getsize(full)])
    return rows


def existing_catalog(html):
    order, credits = {}, {}
    for index, block in DAY_RE.findall(html):
        term = TERMS[int(index) - 1][0]
        names = []
        for name, credit in CARD_RE.findall(block):
            names.append(name)
            credits[(term, name)] = float(credit) if credit else None
        order[term] = names
    return order, credits


def build_catalog(terms_data):
    blocks = []
    for number, (term, code) in enumerate(TERMS, 1):
        courses = terms_data[term]
        total = sum(course["credits"] or 0 for course in courses)
        rows = max(1, round(len(courses) / 2 + 0.1))
        items = "".join(
            '<li class="course"><a class="cname" href="course.html?course={href}">{name}</a>'
            '<span class="ccred">{credit}</span></li>'.format(
                href=quote("{}/{}".format(term, course["name"]), safe=""),
                name=course["name"],
                credit=("%.1f" % course["credits"]) if course["credits"] is not None else "")
            for course in courses)
        blocks.append(
            '        <article class="day" data-reveal id="term-{n}">\n'
            '          <div class="day-head">\n'
            '            <span class="day-no">{n:02d}</span>\n'
            '            <h3 class="day-title">{term}</h3>\n'
            '            <span class="day-meta">{code}　·　{count} 门　·　{total:.1f} 学分</span>\n'
            '          </div>\n'
            '          <ul class="day-grid" style="--rows:{rows}">{items}</ul>\n'
            '        </article>'.format(
                n=number, term=term, code=code, count=len(courses),
                total=total, rows=rows, items=items))
    return "\n".join(blocks)


def build_nav(terms_data):
    links = []
    for number, (term, _) in enumerate(TERMS, 1):
        courses = terms_data[term]
        total = sum(course["credits"] or 0 for course in courses)
        links.append('          <a href="#term-{n}"><strong>{term}</strong>'
                     '<span>{count} 门 · {total:.1f} 学分</span></a>'.format(
                         n=number, term=term, count=len(courses), total=total))
    return ('<nav class="semester-nav" aria-label="按学期跳转">\n'
            + "\n".join(links) + "\n        </nav>")


def replace_once(pattern, replacement, text, label):
    new, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("首页结构已变化，找不到：" + label)
    return new


def main():
    with open(os.path.join(DOCS, "index.html"), encoding="utf-8") as handle:
        html = handle.read()

    order, known = existing_catalog(html)
    terms_data = {}
    manifest = {"generated": "", "branch": BRANCH, "courses": {}}
    missing_credits, added, dropped = [], [], []

    for term, _ in TERMS:
        directory = os.path.join(ROOT, term)
        names = sorted(d for d in os.listdir(directory)
                       if os.path.isdir(os.path.join(directory, d)) and not d.startswith("."))
        previous = order.get(term, [])
        ordered = [name for name in previous if name in names]
        ordered += [name for name in names if name not in ordered]
        dropped += [name for name in previous if name not in names]
        added += [name for name in ordered if name not in previous]
        courses = []
        for name in ordered:
            data = read_course(term, name) or {
                "name": name, "term": term,
                "credits": known.get((term, name)), "notes": False,
            }
            if data["credits"] is None:
                missing_credits.append("{}/{}".format(term, name))
                data["credits"] = known.get((term, name))
            if data["credits"] is None:
                data["credits"] = 0.0
            data["files"] = scan_files(term, name)
            courses.append(data)
            manifest["courses"]["{}/{}".format(term, name)] = {
                "name": name, "term": term, "credits": data["credits"],
                "notes": data["notes"], "files": data["files"],
            }
        terms_data[term] = courses

    total_courses = sum(len(courses) for courses in terms_data.values())
    total_credits = sum(course["credits"] for courses in terms_data.values() for course in courses)

    catalog = "  <!-- catalog:start -->\n" + build_catalog(terms_data) + "\n  <!-- catalog:end -->"
    if "<!-- catalog:start -->" in html:
        html = replace_once(r"  <!-- catalog:start -->.*?  <!-- catalog:end -->", catalog, html, "catalog")
    else:
        first = html.index('  <article class="day" data-reveal id="term-1">')
        last = html.index("        </article>", html.rindex('id="term-6"')) + len("        </article>")
        html = html[:first] + catalog + html[last:]

    html = replace_once(r'<nav class="semester-nav" aria-label="按学期跳转">.*?</nav>',
                        build_nav(terms_data), html, "semester-nav")
    html = replace_once(r'(<div><dt>课程记录</dt><dd>)\d+(<small>门</small></dd></div>)',
                        r"\g<1>{}\g<2>".format(total_courses), html, "hero-course-count")
    html = replace_once(r'(<div><dt>已修学分</dt><dd>)[\d.]+(</dd></div>)',
                        r"\g<1>{:.1f}\g<2>".format(total_credits), html, "hero-credits")
    html = replace_once(r"六个学期，<strong>\d+ 门课</strong>",
                        "六个学期，<strong>{} 门课</strong>".format(total_courses), html, "hero-intro")
    html = replace_once(r'(<meta name="description" content="浙江大学信息工程 2023–2026 六个学期的课程档案：)\d+( 门课的记录)',
                        r"\g<1>{}\g<2>".format(total_courses), html, "meta-description")
    html = replace_once(r'(<meta property="og:description" content=")\d+ 门课 · [\d.]+ 学分',
                        r"\g<1>{} 门课 · {:.1f} 学分".format(total_courses, total_credits),
                        html, "og-description")
    html = replace_once(r"var totalCourses = \d+;", "var totalCourses = {};".format(total_courses),
                        html, "totalCourses")

    with open(os.path.join(DOCS, "index.html"), "w", encoding="utf-8") as handle:
        handle.write(html)

    manifest["generated"] = __import__("datetime").date.today().isoformat()
    manifest["totals"] = {"courses": total_courses, "credits": round(total_credits, 1)}
    os.makedirs(os.path.join(DOCS, "data"), exist_ok=True)
    with open(os.path.join(DOCS, "data", "courses.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, separators=(",", ":"))

    urls = [SITE + "/"] + [
        "{}/course.html?course={}".format(SITE, quote(key, safe=""))
        for key in manifest["courses"]
    ]
    sitemap = ['<?xml version="1.0" encoding="UTF-8"?>',
               '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    sitemap += ["  <url><loc>{}</loc></url>".format(url.replace("&", "&amp;")) for url in urls]
    sitemap.append("</urlset>")
    with open(os.path.join(DOCS, "sitemap.xml"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(sitemap) + "\n")
    with open(os.path.join(DOCS, "robots.txt"), "w", encoding="utf-8") as handle:
        handle.write("User-agent: *\nAllow: /\nSitemap: {}/sitemap.xml\n".format(SITE))

    print("{} 门课 · {:.1f} 学分 · 清单 {:.0f} KB".format(
        total_courses, total_credits,
        os.path.getsize(os.path.join(DOCS, "data", "courses.json")) / 1024))
    if added:
        print("新增：", "、".join(added))
    if dropped:
        print("移除：", "、".join(dropped))
    if missing_credits:
        print("缺学分（已沿用首页旧值）：", "、".join(missing_credits))


if __name__ == "__main__":
    main()
