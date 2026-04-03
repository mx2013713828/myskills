import os
import re

def audit_environment():
    files = ["plan.md", "roadmap.md", "GEMINI.md", "feynman.md"]
    status = {}
    for f in files:
        status[f] = os.path.exists(f)
    
    current_task = "Unknown"
    if status["roadmap.md"]:
        with open("roadmap.md", "r", encoding="utf-8") as f:
            content = f.read()
            # 查找第一个“进行中”的任务
            match = re.search(r"\|[^|]*\|[^|]*\|[^|]*⏳ 进行中\s*\|", content)
            if match:
                line = match.group(0)
                parts = [p.strip() for p in line.split("|") if p.strip()]
                current_task = parts[2] if len(parts) > 2 else "Unknown"
            else:
                # 查找第一个“未开始”的任务
                match = re.search(r"\|[^|]*\|[^|]*\|[^|]*⬜ 未开始\s*\|", content)
                if match:
                    line = match.group(0)
                    parts = [p.strip() for p in line.split("|") if p.strip()]
                    current_task = parts[2] if len(parts) > 2 else "Unknown"

    return {
        "file_status": status,
        "current_task": current_task
    }

if __name__ == "__main__":
    import json
    print(json.dumps(audit_environment(), ensure_ascii=False))
