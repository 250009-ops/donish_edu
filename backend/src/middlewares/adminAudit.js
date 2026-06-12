import { query } from "../db/pool.js";

export function auditAdmin(action) {
  return (req, res, next) => {
    res.on("finish", () => {
      if (res.statusCode >= 400 || !req.admin) return;
      query(
        `insert into admin_audit_log (admin_id, action, target, meta, ip)
         values ($1, $2, $3, $4::jsonb, $5)`,
        [
          req.admin.id,
          action,
          req.auditTarget || null,
          JSON.stringify(req.auditMeta || {}),
          req.ip || null
        ]
      ).catch(() => {});
    });
    next();
  };
}
