
عنوان الملف: n8n-chain-authenticated-Api-requests.txt

=============================
🚀 شرح عملي: سلسلة طلبات API كل واحد فيهم محتاج Token جوّه n8n
=============================

في الملف ده هنمشي خطوة خطوة إزاي تبني Workflow في n8n يكلّم 3 APIs ورا بعض:
- كل واحد فيهم محتاج Token
- وكل واحد بيبعت بيانات جاية من اللي قبله

هنمشي على مثال بسيط:
1) API أول بياخد Token ويرجع بيانات
2) API تاني بياخد جزء من بيانات الأول + Token
3) API ثالث بياخد بيانات من التاني + Token

كل ده من غير كود، كله من الـ UI بتاع n8n 😎


=============================
1️⃣ الفكرة العامة للـ Workflow
=============================

تخيّل معايا السيناريو ده:

- أول Node: بتكلّم API رقم 1  
  – يبعت Token في الـ Headers  
  – يرجّع مثلاً: userId, email, إلخ…

- تاني Node: بتكلّم API رقم 2  
  – ياخد userId اللي رجع من الأول  
  – يبعت كمان Token بتاعه  
  – يرجّع مثلاً: sessionId أو orderId

- تالت Node: بتكلّم API رقم 3  
  – ياخد sessionId من التاني  
  – يبعت Token بتاعه  
  – يرجعلك النتيجة النهائية اللي محتاجها

الربط بينهم بيتم عن طريق حاجة اسمها **Expressions** في n8n:
- يعني تجيب قيمة من Node وتبعتها في Node تاني.


=============================
2️⃣ نقطة البداية في الـ Workflow
=============================

علشان نجرب، نعمل الآتي:

1. افتح n8n
2. اعمل Workflow جديد
3. اختار Node بداية:
   - Manual Trigger لو عايز تشغّل بيدك
   - أو Webhook لو هتستقبل بيانات من برّه
   - أو Cron لو عايزه يشتغل كل فترة لوحده

في الشرح ده، هنمشي على Manual Trigger علشان التجارب.


=============================
3️⃣ Node رقم 1 – أول API بياخد Token
=============================

1. اضغط على زر + في n8n
2. اختار Node من نوع **HTTP Request**
3. سمّي الـ Node مثلاً:
   - `API 1 - Get Data`

إعدادات الـ Node:

- **Method**: اختار GET أو POST حسب الـ API
- **URL**: حط لينك الـ API، مثلاً:
  - `https://api.example.com/v1/users`


🎫 إضافة الـ Token (الطريقة السهلة)

عندك طريقتين:

-----------------------------
🔹 الطريقة 1: تحط الـ Token في Headers يدويًا
-----------------------------

1. في Node الـ HTTP Request:
   - انزل على قسم **Headers**
   - اضغط **Add Header**
2. في Name:
   - اكتب: `Authorization`
3. في Value:
   - لو Bearer Token:
     - `Bearer YOUR_TOKEN_HERE`
   - أو حسب الـ API:
     - `Token xxx`
     - `Api-Key xxx`

-----------------------------
🔹 الطريقة 2: تستخدم Credentials (أنضف وأأمن)
-----------------------------

1. في نفس الـ Node عند خانة Authentication:
   - اختار نوع Auth المناسب (Header Auth, API Key, OAuth2…)
2. اضغط New جنب Credentials
3. دخّل الـ Token مرّة واحدة
4. بعد كده تقدر تستخدم نفس الـ Credentials في أي Node تانية بسهولة


✅ جرّب الـ Node:
- اضغط Execute Node
- لو كله تمام، هتشوف Output JSON، مثلاً:

```json
{
  "userId": 123,
  "name": "Ali",
  "email": "ali@example.com"
}
```


=============================
4️⃣ Node رقم 2 – API تاني بياخد بيانات من الأول + Token
=============================

دلوقتي عايزين نبعِت userId اللي رجع من API 1 إلى API 2.

1. اعمل Node جديد من نوع **HTTP Request**
2. سمّيه:
   - `API 2 - Process User`
3. وصّل السهم من `API 1 - Get Data` إلى `API 2 - Process User`

إعدادات أساسية:

- **Method**: مثلاً POST
- **URL**:  
  `https://api.example.com/v1/process-user`

نفترض إن الـ API التاني محتاج userId في الـ Body:

1. تحت **Body Content Type**:
   - اختار: `JSON`
2. تحت Body Parameters:
   - اضغط Add Field
   - Name: اكتب `userId`
   - Value: هنا هنستخدم Expression

-----------------------------
🧠 إزاي نكتب Expression؟
-----------------------------

1. جنب خانة Value اضغط على الأيقونة الصغيرة → Add Expression
2. هيظهرلك محرّر Expressions
3. اكتب:

```js
{{$node["API 1 - Get Data"].json["userId"]}}
```

ده معناه:
- هات قيمة userId من Output الـ Node اللي اسمه `API 1 - Get Data`

لو الـ JSON كان جوّه طبقات مثلاً:

```json
{
  "data": {
    "user": {
      "id": 123
    }
  }
}
```

يبقى الـ Expression:

```js
{{$node["API 1 - Get Data"].json["data"]["user"]["id"]}}
```


🎫 إضافة Token للـ API التاني:

نفس الفكرة:
- يا إمّا تستخدم Credentials جديدة للـ API التاني
- يا إمّا تحط Header:
  - `Authorization: Bearer SECOND_API_TOKEN`


✅ جرّب Node رقم 2:
- اضغط Execute Node
- هتشوف Output جديد، مثلاً:

```json
{
  "sessionId": "abc-123-xyz",
  "status": "ok"
}
```


=============================
5️⃣ Node رقم 3 – API ثالث بياخد بيانات من التاني + Token
=============================

1. اعمل Node جديد من نوع **HTTP Request**
2. سمّيه:
   - `API 3 - Final Action`
3. وصّل السهم من `API 2 - Process User` إلى `API 3 - Final Action`

إعدادات أساسية:

- **Method**: مثلاً POST
- **URL**:  
  `https://api.example.com/v1/final-action`

نفترض إن الـ API التالت محتاج sessionId:

1. تحت Body Parameters:
   - Name: `sessionId`
   - Value: اعمل **Add Expression** واكتب:

```js
{{$node["API 2 - Process User"].json["sessionId"]}}
```

لو القيمة جوّه data.session.id مثلاً:

```js
{{$node["API 2 - Process User"].json["data"]["session"]["id"]}}
```


🎫 Token بتاع الـ API التالت:

- برضه نفس القصة:
  - يا Credentials
  - يا Headers يدوي:
    - `Authorization: Bearer THIRD_API_TOKEN`


✅ تشغيل السلسلة كاملة:

1. شغل الـ Workflow من Manual Trigger
2. n8n هيمشي بالترتيب:
   - Manual Trigger → API 1 → API 2 → API 3
3. راجع كل Node وتأكّد إن الـ Output مظبوط.


=============================
6️⃣ لو الـ Token بييجي من API Login
=============================

أحيانًا الـ APIs بتشتغل كده:
1. تكلم `/login` أو `/auth`
2. يرجعلك `access_token`
3. تستخدمه في كل الطلبات اللي بعدها

في n8n:

- اعمل Node:
  - `Login API` (برضه HTTP Request)
- الـ Output مثلاً:

```json
{
  "access_token": "XYZ123"
}
```

بعد كده في أي Node تانية (API 1, API 2, API 3):

- في Header بتاع Authorization:
  - افتح Expression واكتب:

```js
{{
  "Bearer " + $node["Login API"].json["access_token"]
}}
```


=============================
7️⃣ شوية تحسينات تخليك شغّال بروفيشنال 😎
=============================

✅ 1) استخدم Credentials بدل ما تخزن الـ Tokens نص عادي في الـ Nodes
- ده أأمن وأسهل لو حبيت تغيّر الـ Token بعدين.

✅ 2) استخدم Node من نوع Set
- علشان تعيد تشكيل البيانات قبل ما تبعتها لـ API تاني
- مثلاً تغيّر اسم حقل من id لـ userId

✅ 3) Error Handling
- ممكن تعمل Workflow مخصوص للأخطاء
- أو تحط IF Node:
  - لو Status Code مش 200
  - ابعت رسالة Slack / Email
  - أو وقّف الـ Flow


=============================
8️⃣ ملخّص سريع للخطوات
=============================

1. Manual Trigger أو Webhook أو Cron كبداية
2. **Node 1 – API 1**:
   - HTTP Request + Token + URL
3. **Node 2 – API 2**:
   - ياخد بيانات من Node 1 باستخدام Expressions
   - يضيف Token
4. **Node 3 – API 3**:
   - ياخد بيانات من Node 2 باستخدام Expressions
   - يضيف Token
5. (اختياري) Node أخيرة:
   - تحفظ النتيجة في Database
   - أو تبعتها Webhook
   - أو تبعتها Email/Slack

لو فضلت تايه في Expressions:
- دايمًا فاكر الشكل ده:

```js
{{$node["اسم الـ Node بالظبط"].json["اسم_الحقل"]}}
```

وكل ما الـ JSON يبقى جوّه طبقات، تزود ["اسم_الحقل"] ورا بعض.

========================================
خلصنا 🎉
========================================


