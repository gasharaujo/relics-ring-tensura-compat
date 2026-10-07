package dev.codex.relicstensuraep.mixin;

import it.hurts.sskirillss.relics.utils.EntityUtils;
import net.minecraft.core.Holder;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

import java.util.Set;

@Mixin(
    targets = "it.hurts.sskirillss.relics.items.relics.ring.RingOfTheSevenDeadlySinsItem",
    remap = false
)
public abstract class RingGluttonyEpCompatMixin {
    private static final Set<String> GLUTTONY_PROTECTED_ATTRIBUTES = Set.of(
        "tensura:max_magicule",
        "tensura:max_aura",
        "tensura:limited_spiritual_max_magicule",
        "tensura:limited_spiritual_max_aura",
        "minecraft:generic.scale"
    );

    @Redirect(
        method = "curioTick(Ltop/theillusivec4/curios/api/SlotContext;Lnet/minecraft/world/item/ItemStack;)V",
        at = @At(
            value = "INVOKE",
            target = "Lit/hurts/sskirillss/relics/utils/EntityUtils;resetAttribute(Lnet/minecraft/world/entity/LivingEntity;Lnet/minecraft/core/Holder;FLnet/minecraft/world/entity/ai/attributes/AttributeModifier$Operation;Lnet/minecraft/resources/ResourceLocation;)V"
        ),
        require = 1,
        remap = false
    )
    private void relicsTensuraEp$keepProtectedAttributesUnmodified(
        LivingEntity entity,
        Holder<Attribute> attribute,
        float value,
        AttributeModifier.Operation operation,
        ResourceLocation modifierId
    ) {
        if (GLUTTONY_PROTECTED_ATTRIBUTES.contains(attribute.getRegisteredName())) {
            EntityUtils.removeAttribute(entity, attribute, operation, modifierId);
            return;
        }

        EntityUtils.resetAttribute(entity, attribute, value, operation, modifierId);
    }
}
