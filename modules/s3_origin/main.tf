resource "aws_s3_bucket" "bucket" {
  force_destroy = true
}

resource "aws_s3_bucket_object" "object" {
  bucket = "${aws_s3_bucket.bucket.bucket}"
  key    = "index.html"

  content      = <<EOF
<script>
const call = (path) => async () => {
	[...document.querySelectorAll("button")].forEach((b) => b.disabled = true);
	const result = await (await fetch(path)).text();
	document.querySelector("#result").innerText = result;
	[...document.querySelectorAll("button")].forEach((b) => b.disabled = false);
}
const call_api = call("/api/");
const call_api_path = call("/api/path");
</script>
<button onclick="call_api()">call /api/</button>
<button onclick="call_api_path()">call /api/path</button>
<p id="result"></p>
EOF
  content_type = "text/html"
}

resource "aws_s3_bucket_policy" "OAI_policy" {
  bucket = "${aws_s3_bucket.bucket.id}"
  policy = "${data.aws_iam_policy_document.s3_policy.json}"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.OAI.iam_arn}"]
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "OAI" {
}

