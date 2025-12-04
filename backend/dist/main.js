"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("reflect-metadata");
const core_1 = require("@nestjs/core");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule, { cors: true });
    app.setGlobalPrefix('api');
    await app.listen(3000);
    console.log('Nite OS backend running on http://localhost:3000/api');
}
bootstrap();
//# sourceMappingURL=main.js.map