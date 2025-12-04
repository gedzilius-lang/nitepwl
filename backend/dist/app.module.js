"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const users_module_1 = require("./modules/users/users.module");
const venues_module_1 = require("./modules/venues/venues.module");
const nitecoin_module_1 = require("./modules/nitecoin/nitecoin.module");
const market_module_1 = require("./modules/market/market.module");
const feed_module_1 = require("./modules/feed/feed.module");
const pos_module_1 = require("./modules/pos/pos.module");
const auth_module_1 = require("./modules/auth/auth.module");
const analytics_module_1 = require("./modules/analytics/analytics.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            users_module_1.UsersModule,
            venues_module_1.VenuesModule,
            nitecoin_module_1.NitecoinModule,
            market_module_1.MarketModule,
            feed_module_1.FeedModule,
            pos_module_1.PosModule,
            auth_module_1.AuthModule,
            analytics_module_1.AnalyticsModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map