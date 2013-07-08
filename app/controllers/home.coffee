
exports.index = (req, res) -> res.render 'home/index'
exports.reset = (req, res) -> res.render 'home/reset', { email: req.body.email or req.query.email }
exports.contact = (req, res) -> res.render 'home/contact'
exports.faq = (req, res) -> res.render 'home/faq'
exports.guide = (req, res) -> res.render 'home/guide'